-- 1_version
version = "0.20.2"

-- 2_plugin_config
local home = os.getenv("HOME")
package.path = home
.. "/.config/xplr/plugins/?/init.lua;"
.. home
.. "/.config/xplr/plugins/?.lua;"
.. package.path

commandMode = require("command-mode")
commandMode.setup()
require("icons").setup()
require("trash-cli").setup()

-- 3_custom_commands
local deployToAEMAuthor = commandMode.cmd("aem deploy author", "Upload and install a content package to AEM Author instance running at http://localhost:4502") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  unzip -t "$XPLR_FOCUS_PATH" &> /dev/null
  exitCode=$?
  if [ "$exitCode" == 0 ]
    then
      # On success should produce result that has lines like these:
      # Package installed in 283ms.
      #     </log>
      #   </data>
      #   <status code="200">ok</status>
      # </response>
      # </crx>
      output=$(curl -s -u admin:admin -F file=@"$XPLR_FOCUS_PATH" -F name="$baseName" -F force=true -F recursive=true -F install=true http://localhost:4502/crx/packmgr/service.jsp)
      result=$(echo "$output" | grep -c 'Package imported\|Package installed\|<status code="200">ok</status>')
      if [ "$result" -gt 2 ] # -gt because multiple packages from the deployed package can be installed
        then
          echo LogSuccess: "Deployed $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to deploy $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to deploy $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local deployToAEMPublish = commandMode.cmd("aem deploy publish", "Upload and install a content package to AEM Publish instance running at http://localhost:4503") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  unzip -t "$XPLR_FOCUS_PATH" &> /dev/null
  exitCode=$?
  if [ "$exitCode" == 0 ]
    then
      # On success should produce result that has lines like these:
      # Package installed in 283ms.
      #     </log>
      #   </data>
      #   <status code="200">ok</status>
      # </response>
      # </crx>
      output=$(curl -s -u admin:admin -F file=@"$XPLR_FOCUS_PATH" -F name="$baseName" -F force=true -F recursive=true -F install=true http://localhost:4503/crx/packmgr/service.jsp)
      result=$(echo "$output" | grep -c 'Package imported\|Package installed\|<status code="200">ok</status>')
      if [ "$result" -gt 2 ] # -gt because multiple packages from the deployed package can be installed
        then
          echo LogSuccess: "Deployed $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to deploy $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to deploy $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local installPackToAEMAuthor = commandMode.cmd("aem install author", "Install a content package to AEM Author instance running at http://localhost:4502") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  allPackages=$(curl -s -u admin:admin http://localhost:4502/crx/packmgr/service.jsp?cmd=ls)
  searchedPackLN=$(echo "$allPackages" | grep -Fn "$baseName" | cut -d : -f 1)
  lnWithPackGroup=$((searchedPackLN - 3))
  if [ $lnWithPackGroup -gt 1 ]
    then
      packGroup=$(echo "$allPackages" | sed -n "${lnWithPackGroup}p" | grep -o -P "(?<=<group>).*(?=</group>)")
      # Will produce result like:
      #  {"success":true,"msg":"Package installed"}
      #  {"success":false,"msg":"no package"}
      output=$(curl -s -u admin:admin -F cmd=install "http://localhost:4502/crx/packmgr/service/.json/etc/packages/$packGroup/$baseName")
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      if [ "$result" == "true" ]
        then
          echo LogSuccess: "Installed $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to install $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to install $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local installPackToAEMPublish = commandMode.cmd("aem install publish", "Install a content package to AEM Publish instance running at http://localhost:4503") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  allPackages=$(curl -s -u admin:admin http://localhost:4502/crx/packmgr/service.jsp?cmd=ls)
  searchedPackLN=$(echo "$allPackages" | grep -Fn "$baseName" | cut -d : -f 1)
  lnWithPackGroup=$((searchedPackLN - 3))
  if [ $lnWithPackGroup -gt 1 ]
    then
      packGroup=$(echo "$allPackages" | sed -n "${lnWithPackGroup}p" | grep -o -P "(?<=<group>).*(?=</group>)")
      # Will produce result like:
      #  {"success":true,"msg":"Package installed"}
      #  {"success":false,"msg":"no package"}
      output=$(curl -s -u admin:admin -F cmd=install "http://localhost:4503/crx/packmgr/service/.json/etc/packages/$packGroup/$baseName")
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      if [ "$result" == "true" ]
        then
          echo LogSuccess: "Installed $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to install $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to install $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local uploadPackToAEMAuthor = commandMode.cmd("aem upload author", "Upload a content package to AEM Author instance running at http://localhost:4502") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  unzip -t "$XPLR_FOCUS_PATH" &> /dev/null
  exitCode=$?
  if [ "$exitCode" == 0 ]
    then
      # Might produce results like:
      #  {"success":true,"msg":"Package uploaded","path":"/etc/packages/my_packages/UNIVERSE.zip"}
      #  {"success":false,"msg":"Zip File is not a content package. Missing 'jcr_root'."}
      #  curl: (7) Failed to connect to localhost port 4502 after 0 ms: Connection refused
      output=$(curl -s -u admin:admin -F cmd=upload -F force=true -F package=@"$XPLR_FOCUS_PATH" http://localhost:4502/crx/packmgr/service/.json)
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      if [ "$result" == "true" ]
        then
          echo LogSuccess: "Uploaded $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to upload $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to upload $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local uploadPackToAEMPublish = commandMode.cmd("aem upload publish", "Upload a content package to AEM Publish instance running at http://localhost:4503") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  unzip -t "$XPLR_FOCUS_PATH" &> /dev/null
  exitCode=$?
  if [ "$exitCode" == 0 ]
    then
      # Might produce results like:
      #  {"success":true,"msg":"Package uploaded","path":"/etc/packages/my_packages/UNIVERSE.zip"}
      #  {"success":false,"msg":"Zip File is not a content package. Missing 'jcr_root'."}
      #  curl: (7) Failed to connect to localhost port 4503 after 0 ms: Connection refused
      output=$(curl -s -u admin:admin -F cmd=upload -F force=true -F package=@"$XPLR_FOCUS_PATH" http://localhost:4503/crx/packmgr/service/.json)
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      if [ "$result" == "true" ]
        then
          echo LogSuccess: "Uploaded $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to upload $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to upload $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local archive = commandMode.cmd("archive", "Package and compress a focused directory into a .zip archive") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  archiveName="$baseName.zip"

  if [ ! -d "$baseName" ]
    then
      echo LogError: "Only existing directories can be archived" >> "${XPLR_PIPE_MSG_IN:?}"
  elif [ -d "$archiveName" ] || [ -f "$archiveName" ]
    then
      echo LogError: "Directory/file '$archiveName' already exists" >> "${XPLR_PIPE_MSG_IN:?}"
  else
      zip -r "$archiveName" "$baseName"
      targetPath=$(realpath "$archiveName")
      echo LogSuccess: "Archived to '$archiveName'" >> "${XPLR_PIPE_MSG_IN:?}"
      echo FocusPath: "$targetPath" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local copyFileContent = commandMode.cmd("copy content", "Copy (cat) the content of a focused file into clipboard") (
        commandMode.BashExecSilently [===[
  fileName=$(basename "$XPLR_FOCUS_PATH")
  if [ -d "$fileName" ]
    then
      echo LogError: "${fileName} is a directory. Copying aborted" >> "${XPLR_PIPE_MSG_IN:?}"
    else
      cat "$fileName" | perl -pe 'chomp if eof' | xclip -selection clipboard
      echo LogSuccess: "Copied content of $fileName into clipboard" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local copyFileName = commandMode.cmd("copy name", "Copy the name of a focused file into clipboard") (
        commandMode.BashExecSilently [===[
  fileName=$(basename "$XPLR_FOCUS_PATH")
  echo "$fileName" | perl -pe 'chomp if eof' | xclip -selection clipboard
  echo LogSuccess: "Copied a file name to the clipboard∶ $fileName" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local copyFilePath = commandMode.cmd("copy path", "Copy the path to a focused file into clipboard") (
        commandMode.BashExecSilently [===[
  echo "$XPLR_FOCUS_PATH" | perl -pe 'chomp if eof' | xclip -selection clipboard
  echo LogSuccess: "Copied a file path to the clipboard∶ $XPLR_FOCUS_PATH" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local decompile = commandMode.cmd("decompile", "Decompile a focused item (normally .jar, .zip or .class file) to a current location") (
        commandMode.BashExec [===[
    fernflowerJar="/usr/share/java/fernflower/fernflower.jar"
    baseName=$(basename -- "$XPLR_FOCUS_PATH")

    generateTargetFolder() {
      echo "${dirNameForFile}/${baseName}_${RANDOM}"
    }

    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk use java 17.0.4-tem # fernflower requires at least Java 17
    echo ""
    echo "Using the following Java:"
    java -version
    dirNameForFile=$(dirname "$XPLR_FOCUS_PATH")
    echo ""

    targetPath="$(generateTargetFolder)"
    while [ -d "$targetPath" ]; do
      targetPath="$(generateTargetFolder)"
    done
    mkdir -p "$targetPath"

    java -jar "$fernflowerJar" "$XPLR_FOCUS_PATH" "$targetPath"
    echo ""

    if [ -z "$(ls -A $targetPath)" ]; then
      trash-put "$targetPath"
      echo "The target path is empty, which might mean that the decompilation failed"
      echo "  -> target path: $targetPath"
      echo "[press Entry to continue]"
      read answer
      echo LogError: "Decompilation might have failed" >> "${XPLR_PIPE_MSG_IN:?}"
    else
      decompiledItem="$targetPath/$baseName"
      unzip "$decompiledItem" -d "$targetPath"
      trash-put "$decompiledItem"
      echo LogSuccess: "Decompiled $XPLR_FOCUS_PATH" >> "${XPLR_PIPE_MSG_IN:?}"
      echo FocusPath: "$targetPath" >> "${XPLR_PIPE_MSG_IN:?}"
    fi
  ]===]
)

local idea = commandMode.cmd("idea", "Open a focused directory in IntelliJ IDEA") (
        commandMode.BashExecSilently [===[
  # Version for IntelliJ IDEA Community:
  # launcherPath="/snap/intellij-idea-community/current/bin/idea.sh"
  # Version for IntelliJ IDEA Ultimate:
  launcherPath="/snap/intellij-idea-ultimate/current/bin/idea.sh"

  if [ ! -f "$launcherPath" ]
    then
      echo LogError: "The IntelliJ IDEA launcher ${launcherPath} hasn't been detected" >> "${XPLR_PIPE_MSG_IN:?}"
      exit 0 # This code must be 0. Otherwise, the above error will not be logged by xplr
  fi

  if [ ! -d "$XPLR_FOCUS_PATH" ]
    then
      echo LogError: "The directory ${XPLR_FOCUS_PATH} doesn't exist" >> "${XPLR_PIPE_MSG_IN:?}"
      exit 0 # This code must be 0. Otherwise, the above error will not be logged by xplr
  fi

  nohup "$launcherPath" nosplash "$XPLR_FOCUS_PATH" > /dev/null 2>&1 &
  echo LogSuccess: "Opened the directory in IntelliJ IDEA∶ ${XPLR_FOCUS_PATH}" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local props = commandMode.cmd("props", "Show size and recursive number of items for a focused directory") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")

  if [ ! -d "$XPLR_FOCUS_PATH" ]
    then
      echo LogError: "The target '$baseName' isn't a valid directory" >> "${XPLR_PIPE_MSG_IN:?}"
      exit 0 # This code must be 0. Otherwise, the above error will not be logged by xplr
  fi       
  
  dirSize=$(du -sh "$XPLR_FOCUS_PATH" | cut -d $'\t' -f 1)
  numOfRecursiveItemsInDirectory=$(find "$XPLR_FOCUS_PATH" -mindepth 1 | wc -l)
  
  echo LogSuccess: "${baseName}∶ $dirSize | $numOfRecursiveItemsInDirectory item(s) recursively" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local unarchive = commandMode.cmd("unarchive", "Unzip/untar/unjar a focused file to a current location") (
        commandMode.BashExecSilently [===[
    dirNameForFile=$(dirname "$XPLR_FOCUS_PATH")

    targetPath=""

    generateTargetFolderName() {
      baseName=$(basename -- "$XPLR_FOCUS_PATH")
      echo "${dirNameForFile}/${baseName}_${RANDOM}"
    }

    mkdirForTargetPath() {
      targetPath="$(generateTargetFolderName)"
      while [ -d "$targetPath" ]; do
          targetPath="$(generateTargetFolderName)"
      done
      mkdir -p "$targetPath"
    }

    finishWithSuccess() {
      echo LogSuccess: "Unarchived $XPLR_FOCUS_PATH" >> "${XPLR_PIPE_MSG_IN:?}"
      echo FocusPath: "$targetPath" >> "${XPLR_PIPE_MSG_IN:?}"
    }

    # Not all archives can be tested/unarchived in the same way.
    # For that reason the script below tries different options.

    # 1. Test with unzip
    unzip -t "$XPLR_FOCUS_PATH" &> /dev/null
    exitCode=$?
    if [ "$exitCode" == 0 ]
      then
        mkdirForTargetPath
        unzip "$XPLR_FOCUS_PATH" -d "$targetPath" &> /dev/null
        finishWithSuccess
      else
        # 2. Test with gzip
        gzip -t "$XPLR_FOCUS_PATH" &> /dev/null
        exitCode=$?

        # 3. Test with tar (possible only by listing a tar archive content)
        if [ "$exitCode" != 0 ]
          then
            tar -tf "$XPLR_FOCUS_PATH" &> /dev/null
            exitCode=$?
        fi

        if [ "$exitCode" == 0 ]
          then
            mkdirForTargetPath
            tar -xf "$XPLR_FOCUS_PATH" --directory "$targetPath" &> /dev/null
            finishWithSuccess
          else
            # 4. Test with 7z
            7z t "$XPLR_FOCUS_PATH" &> /dev/null
            exitCode=$?
            if [ "$exitCode" == 0 ]
              then
                mkdirForTargetPath
                7z x -o"$targetPath" "$XPLR_FOCUS_PATH" &> /dev/null
                finishWithSuccess
              else
                echo LogError: "Invalid source archive. Aborted" >> "${XPLR_PIPE_MSG_IN:?}"
            fi
        fi
    fi
  ]===]
)

-- 4_styling
xplr.config.general.focus_ui.style.bg = "DarkGray"
xplr.config.general.focus_selection_ui.style.bg = "DarkGray"
xplr.fn.builtin.fmt_general_table_row_cols_4 = function(m)
    return tostring(os.date("%Y-%m-%d  %H:%M", m.last_modified / 1000000000))
end
xplr.config.general.show_hidden = true

-- The function below overrides the original function from
-- https://github.com/sayanarijit/xplr/blob/main/src/init.lua
-- in order to not set colors for permissions
xplr.fn.builtin.fmt_general_table_row_cols_2 = function(m)
    local no_color = os.getenv("NO_COLOR")

    local function green(x)
        if no_color == nil then
            return "" .. x .. ""
        else
            return x
        end
    end

    local function yellow(x)
        if no_color == nil then
            return "" .. x .. ""
        else
            return x
        end
    end

    local function red(x)
        if no_color == nil then
            return "" .. x .. ""
        else
            return x
        end
    end

    local function bit(x, color, cond)
        if cond then
            return color(x)
        else
            return color("-")
        end
    end

    local p = m.permissions

    local r = ""

    r = r .. bit("r", green, p.user_read)
    r = r .. bit("w", yellow, p.user_write)

    if p.user_execute == false and p.setuid == false then
        r = r .. bit("-", red, p.user_execute)
    elseif p.user_execute == true and p.setuid == false then
        r = r .. bit("x", red, p.user_execute)
    elseif p.user_execute == false and p.setuid == true then
        r = r .. bit("S", red, p.user_execute)
    else
        r = r .. bit("s", red, p.user_execute)
    end

    r = r .. bit("r", green, p.group_read)
    r = r .. bit("w", yellow, p.group_write)

    if p.group_execute == false and p.setuid == false then
        r = r .. bit("-", red, p.group_execute)
    elseif p.group_execute == true and p.setuid == false then
        r = r .. bit("x", red, p.group_execute)
    elseif p.group_execute == false and p.setuid == true then
        r = r .. bit("S", red, p.group_execute)
    else
        r = r .. bit("s", red, p.group_execute)
    end

    r = r .. bit("r", green, p.other_read)
    r = r .. bit("w", yellow, p.other_write)

    if p.other_execute == false and p.setuid == false then
        r = r .. bit("-", red, p.other_execute)
    elseif p.other_execute == true and p.setuid == false then
        r = r .. bit("x", red, p.other_execute)
    elseif p.other_execute == false and p.setuid == true then
        r = r .. bit("T", red, p.other_execute)
    else
        r = r .. bit("t", red, p.other_execute)
    end

    return r
end
