#!/usr/bin/env python3
"""Serves npm package tarballs as a registry on a local port, for a SNAPSHOT harness whose packages are unpublished.

A released harness's npm packages install from the public registry, but a SNAPSHOT's are never published, and a
node project must install a harness package by its version from a registry rather than from a path, because the
wiring and release-age gates refuse a path. This answers the package-document and tarball requests for the
tarballs it is given. Each tarball is read when it is requested, so a tarball packed after the registry started is
served as it is now. The harness tarballs are dated now, as a fresh release is; the others are dated years back, so
the release-age floor admits them.

A harness package is scoped, such as one under @airness, and is routed here by a scope line alone, so every other
package keeps the registry it is installed from and every other request is answered as not found.

    npm-registry.py (--port <port> | --port-file <file>) --fresh <tarball> ... [--old <tarball> ...]
                    [--npmrc <file> --scope <scope>] [--lockfile <pnpm-lock.yaml>]
    npm-registry.py --refresh-with <pnpm> --lockfile <pnpm-lock.yaml> --fresh <tarball> ...

Every --fresh and --old adds the tarballs after it to the ones named before, so `--fresh a b` and
`--fresh a --fresh b` serve the same two.

With --npmrc it writes the scope line naming the bound port into that file before the port file, so a build that
waits for the port file finds the configuration already in place. --npmrc needs --scope.

With --lockfile it first compares the sha512 integrity of each --fresh tarball, byte for byte, with the one the
lockfile records for that exact name@version, and exits with an error before binding when they differ, rather
than leave a frozen install to refuse the tarball later. It also exits so when an importer whose package.json asks
for a --fresh tarball's exact version records another specifier for that package in the lockfile, or none, as a
lock written before a harness version bump does. A package the lockfile resolves at another version that no
package.json asks for, or a lockfile that does not exist yet, is no mismatch. The error names the command that
refreshes the lock: start this
registry again without --lockfile and, once it serves and the .npmrc routes the package to it, run in the
lockfile's directory, with the pnpm the harness pins under <local Maven repository>/.airness/toolchain:

    pnpm_config_cache_dir="$(mktemp -d)" pnpm install --lockfile-only --fix-lockfile --ignore-scripts

A lockfile-only install keeps an integrity the lockfile already records unless --fix-lockfile resolves the entry
again, and pnpm would resolve it from the package document it cached for a registry address, which names the
old integrity, hence the fresh cache. A workspace keeps one lockfile, at its root, so the command runs there.

With --refresh-with it serves nothing: it runs that refresh itself, with the given pnpm, found on the search path
when it is a bare name, once a registry this helper started serves the tarballs and the .npmrc routes their scope
to it. It refreshes a lock that is stale, or that a merge left with conflict markers, which pnpm resolves, and
leaves any other lock as it is. Having refreshed one, it exits with an error, so a build that binds it before its
frozen install stops rather than going on with a tracked file it rewrote; the next build runs on the refreshed
lock. Under a CI variable that is set and is not false or 0, it refreshes nothing and fails as the check above
does, so a branch whose committed lock is stale fails there.

With --port it binds that port and fails when the port is taken. With --port-file it binds a free port and
writes it into the file once it serves. It stops when the process that started it is gone, so an interrupted
build leaves no server behind, and a SIGTERM stops it with exit 0, as the build that started it ends it.
"""

import argparse
import base64
import hashlib
import io
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

OLD_RELEASE = '2020-01-01T00:00:00.000Z'
PARENT_POLL_SECONDS = 2


def manifest_of(content):
    with tarfile.open(fileobj=io.BytesIO(content), mode='r:gz') as archive:
        member = archive.extractfile('package/package.json')
        if member is None:
            raise ValueError('the tarball holds no package/package.json')
        return json.load(io.TextIOWrapper(member, encoding='utf-8'))


def read(tarball):
    with open(tarball, 'rb') as stream:
        return stream.read()


def integrity_of(content):
    return 'sha512-' + base64.b64encode(hashlib.sha512(content).digest()).decode()


# The integrity pnpm-lock.yaml records under packages for each name@version key, read from its inline
# resolution, as in:   '@airness/node@1.0.9':\n    resolution: {integrity: sha512-...}
def locked_integrities(lockfile):
    if not os.path.isfile(lockfile):
        return {}
    with open(lockfile, encoding='utf-8') as stream:
        text = stream.read()
    section = re.search(r'^packages:\n(.*?)(?=^\S|\Z)', text, re.MULTILINE | re.DOTALL)
    if section is None:
        return {}
    entries = re.finditer(
        r"^  '?/?([^'\s][^']*?)'?:\n    resolution: \{[^}\n]*?integrity: ([^,}\s]+)", section.group(1), re.MULTILINE
    )
    return {entry.group(1): entry.group(2) for entry in entries}


def unquoted(value):
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        return value[1:-1]
    return value


# The specifier pnpm-lock.yaml records for each dependency of each importer, keyed by the importer's path relative
# to the lockfile and then by the dependency's name, read from its importers section, as in:
#   importers:\n\n  .:\n    devDependencies:\n      '@airness/node':\n        specifier: 1.0.9
def locked_specifiers(lockfile):
    if not os.path.isfile(lockfile):
        return {}
    with open(lockfile, encoding='utf-8') as stream:
        text = stream.read()
    section = re.search(r'^importers:\n(.*?)(?=^\S|\Z)', text, re.MULTILINE | re.DOTALL)
    if section is None:
        return {}
    specifiers = {}
    importer = dependency = None
    for line in section.group(1).splitlines():
        content = line.strip()
        if not content:
            continue
        indent = len(line) - len(line.lstrip(' '))
        if indent == 2:
            importer = unquoted(content.removesuffix(':'))
            dependency = None
            specifiers.setdefault(importer, {})
        elif indent == 4:
            dependency = None
        elif indent == 6 and importer is not None:
            dependency = unquoted(content.removesuffix(':'))
        elif indent == 8 and dependency is not None and content.startswith('specifier: '):
            specifiers[importer][dependency] = unquoted(content.removeprefix('specifier: '))
    return specifiers


# Whether the package.json of the importer at the path given, relative to the lockfile's directory, asks for the
# exact version given of the named package, as a dependency of any kind pnpm locks.
def asks_for(lockfile, importer, name, version):
    path = os.path.join(os.path.dirname(os.path.abspath(lockfile)), importer, 'package.json')
    if not os.path.isfile(path):
        return False
    with open(path, encoding='utf-8') as stream:
        manifest = json.load(stream)
    kinds = ('dependencies', 'devDependencies', 'optionalDependencies')
    return any(isinstance(manifest.get(kind), dict) and manifest[kind].get(name) == version for kind in kinds)


# Each reason a frozen install would refuse what this registry serves: a served name@version the lockfile records
# another integrity for, and an importer that asks for a served version the lockfile records no specifier of.
def stale_entries(arguments):
    locked = locked_integrities(arguments.lockfile)
    specifiers = locked_specifiers(arguments.lockfile)
    stale = []
    for path in arguments.fresh:
        if not os.path.isfile(path):
            continue
        content = read(path)
        manifest = manifest_of(content)
        name, version = manifest['name'], manifest['version']
        key = f'{name}@{version}'
        served = integrity_of(content)
        if key in locked and locked[key] != served:
            stale.append(f'{key}: the lockfile records {locked[key]}, but {path} has {served}')
        for importer, dependencies in specifiers.items():
            recorded = dependencies.get(name)
            if recorded != version and asks_for(arguments.lockfile, importer, name, version):
                held = f'specifier {recorded}' if recorded is not None else 'no specifier'
                stale.append(
                    f'{name} in importer {importer}: its package.json asks for {version}, which {path} serves, but'
                    f' the lockfile records {held}'
                )
    return stale


def stale_lines(arguments, stale):
    lines = [f'the lockfile {arguments.lockfile} is stale, so a frozen install would refuse what this registry serves:']
    lines.extend(f'  {entry}' for entry in stale)
    return lines


def refuse_stale_lock(arguments):
    stale = stale_entries(arguments)
    if not stale:
        return
    # The same invocation without the lockfile check, so the registry it starts serves what this one would.
    restart = [sys.argv[0]]
    given = iter(sys.argv[1:])
    for argument in given:
        if argument == '--lockfile':
            next(given, None)
        elif not argument.startswith('--lockfile='):
            restart.append(argument)
    lines = stale_lines(arguments, stale)
    directory = shlex.quote(os.path.dirname(os.path.abspath(arguments.lockfile)))
    lines += [
        'Refresh the lock against this registry. Start it without --lockfile:',
        f'  python3 {shlex.join(restart)}',
        'and, once it serves and the .npmrc routes the package to it, run with the pnpm the harness pins under',
        '<local Maven repository>/.airness/toolchain/pnpm-<version>-<platform>/pnpm:',
        f'  cd {directory} && pnpm_config_cache_dir="$(mktemp -d)" pnpm install --lockfile-only --fix-lockfile'
        ' --ignore-scripts',
        'Both the flag and the fresh cache matter: without --fix-lockfile the install keeps the recorded integrity,',
        'and pnpm would resolve again from the package document it cached for this registry address.',
    ]
    sys.exit('\n'.join(lines))


# Whether a CI variable says the build runs in CI, as GitHub Actions and most CI services set it.
def in_ci():
    return os.environ.get('CI', '').strip().lower() not in ('', 'false', '0')


# The environment the build runs pnpm with: the pnpm's own directory first on the search path, and no inherited
# setting with which pnpm would pick a pnpm or a Node of its own.
def pnpm_environment(pnpm):
    selecting = {
        prefix + setting
        for prefix in ('npm_config_', 'pnpm_config_')
        for setting in (
            'manage_package_manager_versions', 'use_node_version', 'node_version', 'execution_env', 'pm_on_fail'
        )
    }
    environment = {name: value for name, value in os.environ.items() if name.lower() not in selecting}
    environment['npm_config_manage_package_manager_versions'] = 'false'
    environment['pnpm_config_manage_package_manager_versions'] = 'false'
    environment['PATH'] = os.path.dirname(os.path.abspath(pnpm)) + os.pathsep + environment.get('PATH', '')
    return environment


def conflicted(lockfile):
    if not os.path.isfile(lockfile):
        return False
    with open(lockfile, encoding='utf-8') as stream:
        return any(line.startswith(('<<<<<<< ', '>>>>>>> ')) for line in stream)


def lock_problems(arguments):
    if conflicted(arguments.lockfile):
        return [f'the lockfile {arguments.lockfile} holds merge conflict markers']
    stale = stale_entries(arguments)
    return stale_lines(arguments, stale) if stale else []


def refresh_stale_lock(arguments):
    problems = lock_problems(arguments)
    if not problems:
        print(f'The lockfile {arguments.lockfile} records the version and integrity of each served tarball')
        return
    if in_ci():
        sys.exit('\n'.join(problems + [
            'CI refreshes no lock. Build on your own machine, where the build refreshes it, and commit the lockfile.',
        ]))
    pnpm = shutil.which(arguments.refresh_with)
    if pnpm is None:
        sys.exit(
            f'no pnpm {arguments.refresh_with} to refresh the stale lock with; install the pinned pnpm, as the build of'
            ' any node module does, and build again'
        )
    directory = os.path.dirname(os.path.abspath(arguments.lockfile))
    print('\n'.join(problems + [f'Refreshing it with {pnpm}']), flush=True)
    with tempfile.TemporaryDirectory() as cache:
        environment = pnpm_environment(pnpm)
        environment['pnpm_config_cache_dir'] = cache
        refreshed = subprocess.run(
            [pnpm, 'install', '--lockfile-only', '--fix-lockfile', '--ignore-scripts'],
            cwd=directory,
            env=environment,
            check=False,
        )
    if refreshed.returncode != 0:
        sys.exit(f'the refresh of {arguments.lockfile} exited {refreshed.returncode}; its output is above')
    left = lock_problems(arguments)
    if left:
        sys.exit('\n'.join(['the refresh did not repair the lock:'] + left))
    sys.exit(
        f'Refreshed {arguments.lockfile}, a tracked file, so this build stops here. Build again, and commit the\n'
        'lockfile with the change that altered the served tarballs.'
    )


def parse_arguments():
    parser = argparse.ArgumentParser(description='Serve npm tarballs as a local registry.')
    where = parser.add_mutually_exclusive_group(required=True)
    where.add_argument('--port', type=int)
    where.add_argument('--port-file')
    where.add_argument('--refresh-with', help='the pnpm with which to refresh a stale --lockfile, serving nothing')
    # Each occurrence adds its tarballs to the ones named before it, so one flag per tarball and one flag before
    # several name the same set.
    parser.add_argument('--fresh', nargs='+', action='extend', default=[], help='tarballs dated now')
    parser.add_argument('--old', nargs='*', action='extend', default=[], help='tarballs dated years back')
    parser.add_argument('--npmrc', help='the .npmrc to write the scope line into once the port is bound')
    parser.add_argument('--scope', help='the scope the .npmrc routes here, such as @airness')
    parser.add_argument('--lockfile', help='the pnpm-lock.yaml whose integrity each --fresh tarball must match')
    arguments = parser.parse_args()
    if arguments.npmrc and not arguments.scope:
        parser.error('--npmrc needs --scope, the scope the .npmrc routes here')
    if arguments.refresh_with and not arguments.lockfile:
        parser.error('--refresh-with needs --lockfile, the lockfile to refresh')
    return arguments


def main():
    arguments = parse_arguments()
    if arguments.refresh_with:
        refresh_stale_lock(arguments)
        return
    now = datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
    tarballs = [(path, now) for path in arguments.fresh] + [(path, OLD_RELEASE) for path in arguments.old]
    if arguments.lockfile:
        refuse_stale_lock(arguments)

    # Every version given for a name is served; the first one given is the latest.
    def packages():
        served = {}
        for path, published in tarballs:
            if not os.path.isfile(path):
                continue
            content = read(path)
            manifest = manifest_of(content)
            versions = served.setdefault(manifest['name'], {})
            versions.setdefault(manifest['version'], {'manifest': manifest, 'content': content, 'published': published})
        return served

    def tarball_path(name, version):
        return f'/{name}/-/{name.split("/")[-1]}-{version}.tgz'

    class Registry(BaseHTTPRequestHandler):
        def do_GET(self):
            served = packages()
            requested = self.path.replace('%2f', '/').replace('%2F', '/')
            for name, versions in served.items():
                if requested == f'/{name}':
                    self.document(name, versions)
                    return
                for version, package in versions.items():
                    if requested == tarball_path(name, version):
                        self.reply(200, 'application/octet-stream', package['content'])
                        return
            self.reply(404, 'application/json', b'{"error":"not found"}')

        def document(self, name, versions):
            latest = next(iter(versions))
            published = versions[latest]['published']
            document = {
                'name': name,
                'dist-tags': {'latest': latest},
                'time': {
                    **{version: package['published'] for version, package in versions.items()},
                    'created': published,
                    'modified': published,
                },
                'versions': {
                    version: {
                        **package['manifest'],
                        'dist': {
                            'tarball': f'http://{self.headers.get("Host")}{tarball_path(name, version)}',
                            'shasum': hashlib.sha1(package['content']).hexdigest(),
                            'integrity': integrity_of(package['content']),
                        },
                    }
                    for version, package in versions.items()
                },
            }
            self.reply(200, 'application/json', json.dumps(document).encode())

        def reply(self, status, content_type, body):
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *arguments):
            pass

    # The build that starts the registry stops it with SIGTERM once it is done with it. That is how a serving
    # registry is meant to end, so it ends with exit 0 rather than the signal's 143, which Maven reports as a
    # failed process. A refresh keeps the default, so an interrupted refresh still ends as a failure.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        server = ThreadingHTTPServer(('127.0.0.1', arguments.port or 0), Registry)
    except OSError as error:
        sys.exit(f'the local npm registry could not bind port {arguments.port}: {error}')
    parent = os.getppid()

    def stop_with_parent():
        while os.getppid() == parent:
            time.sleep(PARENT_POLL_SECONDS)
        server.shutdown()

    threading.Thread(target=stop_with_parent, daemon=True).start()
    if arguments.npmrc:
        with open(arguments.npmrc, 'w', encoding='utf-8') as stream:
            stream.write(f'{arguments.scope}:registry=http://127.0.0.1:{server.server_address[1]}/\n')
    if arguments.port_file:
        with open(arguments.port_file + '.partial', 'w', encoding='utf-8') as stream:
            stream.write(str(server.server_address[1]))
        os.replace(arguments.port_file + '.partial', arguments.port_file)
    server.serve_forever()


if __name__ == '__main__':
    main()
