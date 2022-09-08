-- This plugin is a modification of this plugin:
-- https://github.com/prncss-xyz/icons.xplr
-- For urther configuration ideas see this plugin:
-- https://github.com/dtomvan/extra-icons.xplr

local function black(x)
  return "\x1b[30m" .. x .. "\x1b[0m"
end

local function red(x)
  return "\x1b[31m" .. x .. "\x1b[0m"
end

local function lightRed(x)
  return "\x1b[38;5;167m" .. x .. "\x1b[0m"
end

local function green(x)
  return "\x1b[32m" .. x .. "\x1b[0m"
end

local function lightGreen(x)
  return "\x1b[38;5;119m" .. x .. "\x1b[0m"
end

local function yellow(x)
  return "\x1b[38;5;226m" .. x .. "\x1b[0m"
end

local function blue(x)
  return "\x1b[38;5;33m" .. x .. "\x1b[0m"
end

local function magenta(x)
  return "\x1b[35m" .. x .. "\x1b[0m"
end

local function cyan(x)
  return "\x1b[36m" .. x .. "\x1b[0m"
end

local function white(x)
  return "\x1b[37m" .. x .. "\x1b[0m"
end

local function orange(x)
  return "\x1b[38;5;214m" .. x .. "\x1b[0m"
end

function setup()
  local xplr = xplr
  
  -- BASIC FILE TYPES	
  xplr.config.node_types.directory.meta.icon = cyan ""
  xplr.config.node_types.file.meta.icon = ""
  xplr.config.node_types.symlink.meta.icon = ""

  -- MIME TYPES
  xplr.config.node_types.mime_essence = {
    audio = {
      ["*"] = { meta = { icon = yellow "" } },
    },
    video = {
      ["*"] = { meta = { icon = "" } },
    },
    image = {
      ["*"] = { meta = { icon = "" } },
    },
    application = {
      zip = { meta = { icon = "" } },
      pdf = { meta = { icon = "" } },
    },
    text = {
      ["*"] = { meta = { icon = "" } },
    },
    font = {
      ["*"] = { meta = { icon = "" } },
    },    
  }

  -- DEFAULT HOME FOLDERS
  xplr.config.node_types.special["Desktop"] = { meta = { icon = "ﲾ" } }
  xplr.config.node_types.special["Documents"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Downloads"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Music"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Pictures"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Public"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Templates"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Videos"] = { meta = { icon = "" } }
  
  -- BASH RELATED
  xplr.config.node_types.special[".bash_history"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".bash_logout"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".bashrc"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".bashprofile"] = { meta = { icon = "" } }
  xplr.config.node_types.extension.bash = { meta = { icon = "" } }
  xplr.config.node_types.extension.sh = { meta = { icon = "" } }
  
  -- COMMON TYPES
  xplr.config.node_types.extension.xml = { meta = { icon = "" } }
  xplr.config.node_types.extension.yaml = { meta = { icon = "" } }
  xplr.config.node_types.extension.yml = { meta = { icon = "" } }
  xplr.config.node_types.extension.conf = { meta = { icon = "" } }
  xplr.config.node_types.extension.config = { meta = { icon = "" } }
  xplr.config.node_types.extension.properties = { meta = { icon = "" } }
  xplr.config.node_types.special["img"] = { meta = { icon = "" } }
  xplr.config.node_types.extension.png = { meta = { icon = "" } }
  xplr.config.node_types.extension.svg = { meta = { icon = "ﰟ" } }
  xplr.config.node_types.special["src"] = { meta = { icon = "" } }
  
  -- GIT RELATED
  xplr.config.node_types.special[".gitconfig"] = { meta = { icon = lightRed "" } }
  xplr.config.node_types.special[".gitmodules"] = { meta = { icon = lightRed "" } }
  xplr.config.node_types.special[".gitignore"] = { meta = { icon = lightRed "" } }
  xplr.config.node_types.special[".gitattributes"] = { meta = { icon = lightRed "" } }
  xplr.config.node_types.extension.git = { meta = { icon = lightRed "" } }
  xplr.config.node_types.special["COMMIT_EDITMSG"] = { meta = { icon = lightRed "" } }
  xplr.config.node_types.special[".git"] = { meta = { icon = lightRed "" } }
  
  -- JAVA RELATED
  xplr.config.node_types.extension.java = { meta = { icon = orange "" } }
  xplr.config.node_types.extension.jar = { meta = { icon = orange "" } }
  xplr.config.node_types.special["pom.xml"] = { meta = { icon = blue "" } }
  
  -- WEB RELATED
  xplr.config.node_types.extension.htm = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.html = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.mjs = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.js = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.jsx = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.scss = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.css = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.ts = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.tsx = { meta = { icon = lightGreen "" } }
  xplr.config.node_types.extension.vue = { meta = { icon = lightGreen "﵂" } }
  
  -- DOCUMENTATION RELATED
  xplr.config.node_types.extension.rmd = { meta = { icon = yellow "" } }
  xplr.config.node_types.extension.Rmd = { meta = { icon = yellow "" } }
  xplr.config.node_types.extension.markdown = { meta = { icon = yellow "" } }
  xplr.config.node_types.extension.md = { meta = { icon = yellow "" } }
  xplr.config.node_types.extension.mdx = { meta = { icon = yellow "" } }
  xplr.config.node_types.extension.adoc = { meta = { icon = yellow "" } }
  
  -- PACKAGES
  xplr.config.node_types.extension.m3u = { meta = { icon = "" } }
  xplr.config.node_types.extension["7z"] = { meta = { icon = "" } }
  xplr.config.node_types.extension.apk = { meta = { icon = "" } }
  xplr.config.node_types.extension.bz2 = { meta = { icon = "" } }
  xplr.config.node_types.extension.cab = { meta = { icon = "" } }
  xplr.config.node_types.extension.cbr = { meta = { icon = "" } }
  xplr.config.node_types.extension.cbr = { meta = { icon = "" } }
  xplr.config.node_types.extension.cbz = { meta = { icon = "" } }
  xplr.config.node_types.extension.cpio = { meta = { icon = "" } }
  xplr.config.node_types.extension.gz = { meta = { icon = "" } }
  xplr.config.node_types.extension.gzip = { meta = { icon = "" } }
  xplr.config.node_types.extension.lha = { meta = { icon = "" } }
  xplr.config.node_types.extension.lzh = { meta = { icon = "" } }
  xplr.config.node_types.extension.lzma = { meta = { icon = "" } }
  xplr.config.node_types.extension.rar = { meta = { icon = "" } }
  xplr.config.node_types.extension.rpm = { meta = { icon = "" } }
  xplr.config.node_types.extension.tar = { meta = { icon = "" } }
  xplr.config.node_types.extension.tgz = { meta = { icon = "" } }
  xplr.config.node_types.extension.txz = { meta = { icon = "" } }
  xplr.config.node_types.extension.xbps = { meta = { icon = "" } }
  xplr.config.node_types.extension.xz = { meta = { icon = "" } }
  xplr.config.node_types.extension.zip = { meta = { icon = "" } }
  
  -- SPECIAL TYPES
  xplr.config.node_types.special["Gemfile"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".vimrc"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".settings.json"] = { meta = { icon = "" } } 
  xplr.config.node_types.special[".npmignore"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".gvimrc"] = { meta = { icon = "" } }
  xplr.config.node_types.special["favicon.ico"] = { meta = { icon = "" } }
  xplr.config.node_types.special["mix.lock"] = { meta = { icon = "" } }
  xplr.config.node_types.special["node_modules"] = { meta = { icon = "" } }
  xplr.config.node_types.special["config.ru"] = { meta = { icon = "" } }
  xplr.config.node_types.special["_vimrc"] = { meta = { icon = "" } }
  xplr.config.node_types.special["_gvimrc"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".babelrc"] = { meta = { icon = "ﬥ" } }
  xplr.config.node_types.special[".gitlab-ci.yml"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Dockerfile"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".zshenv"] = { meta = { icon = "" } }
  xplr.config.node_types.special["CMakeLists.txt"] = { meta = { icon = "" } }
  xplr.config.node_types.special["makefile"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".zprofile"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".ds_store"] = { meta = { icon = "" } }
  xplr.config.node_types.special[".zshrc"] = { meta = { icon = "" } }
  xplr.config.node_types.special["Vagrantfile"] = { meta = { icon = "" } }
  xplr.config.node_types.special["COPYING.LESSER"] = { meta = { icon = "" } }
  xplr.config.node_types.special["LICENSE"] = { meta = { icon = red "" } }
  xplr.config.node_types.special["license"] = { meta = { icon = red "" } }

  --- DEVICONS
  xplr.config.node_types.extension.COPYING = { meta = { icon = "" } }
  xplr.config.node_types.extension.R = { meta = { icon = "ﳒ" } }
  xplr.config.node_types.extension.ai = { meta = { icon = "" } }
  xplr.config.node_types.extension.awk = { meta = { icon = "" } }
  xplr.config.node_types.extension.bat = { meta = { icon = "" } }
  xplr.config.node_types.extension.bmp = { meta = { icon = "" } }
  xplr.config.node_types.extension.c = { meta = { icon = "" } }
  xplr.config.node_types.extension.cc = { meta = { icon = "" } }
  xplr.config.node_types.extension.cfg = { meta = { icon = "" } }
  xplr.config.node_types.extension.clj = { meta = { icon = "" } }
  xplr.config.node_types.extension.cljc = { meta = { icon = "" } }
  xplr.config.node_types.extension.cljs = { meta = { icon = "" } }
  xplr.config.node_types.extension.cmake = { meta = { icon = "" } }
  xplr.config.node_types.extension.coffee = { meta = { icon = "" } }
  xplr.config.node_types.extension.cp = { meta = { icon = "" } }
  xplr.config.node_types.extension.cpp = { meta = { icon = "" } }
  xplr.config.node_types.extension.cs = { meta = { icon = "" } }
  xplr.config.node_types.extension.csh = { meta = { icon = "" } }
  xplr.config.node_types.extension.cson = { meta = { icon = "" } }
  xplr.config.node_types.extension.cxx = { meta = { icon = "" } }
  xplr.config.node_types.extension.d = { meta = { icon = "" } }
  xplr.config.node_types.extension.dart = { meta = { icon = "" } }
  xplr.config.node_types.extension.db = { meta = { icon = "" } }
  xplr.config.node_types.extension.desktop = { meta = { icon = "" } }
  xplr.config.node_types.extension.diff = { meta = { icon = "" } }
  xplr.config.node_types.extension.doc = { meta = { icon = "" } }
  xplr.config.node_types.extension.dockerfile = { meta = { icon = "" } }
  xplr.config.node_types.extension.dropbox = { meta = { icon = "" } }
  xplr.config.node_types.extension.dump = { meta = { icon = "" } }
  xplr.config.node_types.extension.edn = { meta = { icon = "" } }
  xplr.config.node_types.extension.eex = { meta = { icon = "" } }
  xplr.config.node_types.extension.ejs = { meta = { icon = "" } }
  xplr.config.node_types.extension.elm = { meta = { icon = "" } }
  xplr.config.node_types.extension.erb = { meta = { icon = "" } }
  xplr.config.node_types.extension.erl = { meta = { icon = "" } }
  xplr.config.node_types.extension.ex = { meta = { icon = "" } }
  xplr.config.node_types.extension.exs = { meta = { icon = "" } }
  xplr.config.node_types.extension.fish = { meta = { icon = "" } }
  xplr.config.node_types.extension.fs = { meta = { icon = "" } }
  xplr.config.node_types.extension.fsi = { meta = { icon = "" } }
  xplr.config.node_types.extension.fsscript = { meta = { icon = "" } }
  xplr.config.node_types.extension.fsx = { meta = { icon = "" } }
  xplr.config.node_types.extension.gd = { meta = { icon = "" } }
  xplr.config.node_types.extension.gemspec = { meta = { icon = "" } }
  xplr.config.node_types.extension.glb = { meta = { icon = "" } }
  xplr.config.node_types.extension.go = { meta = { icon = "" } }
  xplr.config.node_types.extension.godot = { meta = { icon = "" } }
  xplr.config.node_types.extension.gruntfile = { meta = { icon = "" } }
  xplr.config.node_types.extension.gulpfile = { meta = { icon = "" } }
  xplr.config.node_types.extension.h = { meta = { icon = "" } }
  xplr.config.node_types.extension.haml = { meta = { icon = "" } }
  xplr.config.node_types.extension.hbs = { meta = { icon = "" } }
  xplr.config.node_types.extension.hh = { meta = { icon = "" } }
  xplr.config.node_types.extension.hpp = { meta = { icon = "" } }
  xplr.config.node_types.extension.hrl = { meta = { icon = "" } }
  xplr.config.node_types.extension.hs = { meta = { icon = "" } }
  xplr.config.node_types.extension.hxx = { meta = { icon = "" } }
  xplr.config.node_types.extension.ico = { meta = { icon = "" } }
  xplr.config.node_types.extension.import = { meta = { icon = "" } }
  xplr.config.node_types.extension.ini = { meta = { icon = "" } }
  xplr.config.node_types.extension.jl = { meta = { icon = "" } }
  xplr.config.node_types.extension.json = { meta = { icon = "" } }
  xplr.config.node_types.extension.ksh = { meta = { icon = "" } }
  xplr.config.node_types.extension.kt = { meta = { icon = "𝙆" } }
  xplr.config.node_types.extension.leex = { meta = { icon = "" } }
  xplr.config.node_types.extension.less = { meta = { icon = "" } }
  xplr.config.node_types.extension.lhs = { meta = { icon = "" } }
  xplr.config.node_types.extension.license = { meta = { icon = "" } }
  xplr.config.node_types.extension.lock = { meta = { icon = red "" } }
  xplr.config.node_types.extension.lua = { meta = { icon = blue "" } }
  xplr.config.node_types.extension.material = { meta = { icon = "" } }
  xplr.config.node_types.extension.ml = { meta = { icon = "λ" } }
  xplr.config.node_types.extension.mli = { meta = { icon = "λ" } }
  xplr.config.node_types.extension.mustache = { meta = { icon = "" } }
  xplr.config.node_types.extension.nix = { meta = { icon = "" } }
  xplr.config.node_types.extension.opus = { meta = { icon = "" } }
  xplr.config.node_types.extension.otf = { meta = { icon = "" } }
  xplr.config.node_types.extension.pck = { meta = { icon = "" } }
  xplr.config.node_types.extension.php = { meta = { icon = "" } }
  xplr.config.node_types.extension.pl = { meta = { icon = "" } }
  xplr.config.node_types.extension.pm = { meta = { icon = "" } }
  xplr.config.node_types.extension.pp = { meta = { icon = "" } }
  xplr.config.node_types.extension.ppt = { meta = { icon = "" } }
  xplr.config.node_types.extension.procfile = { meta = { icon = "" } }
  xplr.config.node_types.extension.ps1 = { meta = { icon = "" } }
  xplr.config.node_types.extension.psb = { meta = { icon = "" } }
  xplr.config.node_types.extension.psd = { meta = { icon = "" } }
  xplr.config.node_types.extension.py = { meta = { icon = yellow "" } }
  xplr.config.node_types.extension.pyc = { meta = { icon = "" } }
  xplr.config.node_types.extension.pyd = { meta = { icon = "" } }
  xplr.config.node_types.extension.pyo = { meta = { icon = "" } }
  xplr.config.node_types.extension.r = { meta = { icon = "ﳒ" } }
  xplr.config.node_types.extension.rake = { meta = { icon = "" } }
  xplr.config.node_types.extension.rakefile = { meta = { icon = "" } }
  xplr.config.node_types.extension.rb = { meta = { icon = "" } }
  xplr.config.node_types.extension.rlib = { meta = { icon = "" } }
  xplr.config.node_types.extension.rproj = { meta = { icon = "鉶" } }
  xplr.config.node_types.extension.rs = { meta = { icon = red "" } }
  xplr.config.node_types.extension.rss = { meta = { icon = "" } }
  xplr.config.node_types.extension.sass = { meta = { icon = "" } }
  xplr.config.node_types.extension.scala = { meta = { icon = "" } }
  xplr.config.node_types.extension.slim = { meta = { icon = "" } }
  xplr.config.node_types.extension.sln = { meta = { icon = "" } }
  xplr.config.node_types.extension.sql = { meta = { icon = "" } }
  xplr.config.node_types.extension.styl = { meta = { icon = "" } }
  xplr.config.node_types.extension.suo = { meta = { icon = "" } }
  xplr.config.node_types.extension.svelte = { meta = { icon = "" } }
  xplr.config.node_types.extension.swift = { meta = { icon = "" } }
  xplr.config.node_types.extension.t = { meta = { icon = "" } }
  xplr.config.node_types.extension.terminal = { meta = { icon = "" } }
  xplr.config.node_types.extension.tex = { meta = { icon = "ﭨ" } }
  xplr.config.node_types.extension.toml = { meta = { icon = white "" } }
  xplr.config.node_types.extension.tres = { meta = { icon = "" } }
  xplr.config.node_types.extension.tscn = { meta = { icon = "" } }
  xplr.config.node_types.extension.twig = { meta = { icon = "" } }
  xplr.config.node_types.extension.vim = { meta = { icon = "" } }
  xplr.config.node_types.extension.webmanifest = { meta = { icon = "" } }
  xplr.config.node_types.extension.webpack = { meta = { icon = "ﰩ" } }
  xplr.config.node_types.extension.xcplayground = { meta = { icon = "" } }
  xplr.config.node_types.extension.xls = { meta = { icon = "" } }  
  xplr.config.node_types.extension.xul = { meta = { icon = "" } }
  xplr.config.node_types.extension.zsh = { meta = { icon = "" } }
  xplr.config.node_types.extension["c++"] = { meta = { icon = "" } }
  xplr.config.node_types.extension["f#"] = { meta = { icon = "" } }
end

return { setup = setup }
