-- 1_version
version = "0.19.0"

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
local unarchive = commandMode.cmd("unarchive", "Unzip/untar/unjar a focused file to a current location") (
        commandMode.BashExecSilently [===[
    dirNameForFile=$(dirname "$XPLR_FOCUS_PATH")

    generateTargetFolder() {
      baseName=$(basename -- "$XPLR_FOCUS_PATH")
      baseNameWithoutExtension="${baseName%.*}"
      echo "${dirNameForFile}/${baseNameWithoutExtension}[${RANDOM}]"
    }

    unzip -t "$XPLR_FOCUS_PATH" &> /dev/null
    exitCode=$?
    if [ "$exitCode" == 0 ]
      then
        targetPath="$(generateTargetFolder)"
        while [ -d "$targetPath" ]; do
            targetPath="$(generateTargetFolder)"
        done
        mkdir -p "$targetPath"
        unzip "$XPLR_FOCUS_PATH" -d "$targetPath" &> /dev/null
        echo LogSuccess: "Unarchived $XPLR_FOCUS_PATH" >> "${XPLR_PIPE_MSG_IN:?}"
        echo FocusPath: "$targetPath" >> "${XPLR_PIPE_MSG_IN:?}"
      else
        gzip -t "$XPLR_FOCUS_PATH" &> /dev/null
        exitCode=$?
        if [ "$exitCode" == 0 ]
          then
            targetPath="$(generateTargetFolder)"
            while [ -d "$targetPath" ]; do
                targetPath="$(generateTargetFolder)"
            done
            mkdir -p "$targetPath"
            tar -xf "$XPLR_FOCUS_PATH" --directory "$targetPath" &> /dev/null
            echo LogSuccess: "Unarchived $XPLR_FOCUS_PATH" >> "${XPLR_PIPE_MSG_IN:?}"
            echo FocusPath: "$targetPath" >> "${XPLR_PIPE_MSG_IN:?}"
          else
            echo LogError: "Invalid source archive. Aborted" >> "${XPLR_PIPE_MSG_IN:?}"
        fi
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

local installPackToAEMAuthor = commandMode.cmd("aem install author", "Install a content package to AEM Author instance running at http://localhost:4502") (
        commandMode.BashExecSilently [===[
  packName=$(basename -- "$XPLR_FOCUS_PATH")
  allPackages=$(curl -s -u admin:admin http://localhost:4502/crx/packmgr/service.jsp?cmd=ls)
  searchedPackLN=$(echo "$allPackages" | grep -Fn "$packName" | cut -d : -f 1)
  lnWithPackGroup=$((searchedPackLN - 3))
  if [ $lnWithPackGroup -gt 1 ]
    then
      packGroup=$(echo "$allPackages" | sed -n "${lnWithPackGroup}p" | grep -o -P "(?<=<group>).*(?=</group>)")
      # Will produce result like:
      #  {"success":true,"msg":"Package installed"}
      #  {"success":false,"msg":"no package"}
      output=$(curl -s -u admin:admin -F cmd=install "http://localhost:4502/crx/packmgr/service/.json/etc/packages/$packGroup/$packName")
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      if [ "$result" == "true" ]
        then
          echo LogSuccess: "Installed $packName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to install $packName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to install $packName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local installPackToAEMPublish = commandMode.cmd("aem install publish", "Install a content package to AEM Publish instance running at http://localhost:4503") (
        commandMode.BashExecSilently [===[
  packName=$(basename -- "$XPLR_FOCUS_PATH")
  allPackages=$(curl -s -u admin:admin http://localhost:4502/crx/packmgr/service.jsp?cmd=ls)
  searchedPackLN=$(echo "$allPackages" | grep -Fn "$packName" | cut -d : -f 1)
  lnWithPackGroup=$((searchedPackLN - 3))
  if [ $lnWithPackGroup -gt 1 ]
    then
      packGroup=$(echo "$allPackages" | sed -n "${lnWithPackGroup}p" | grep -o -P "(?<=<group>).*(?=</group>)")
      # Will produce result like:
      #  {"success":true,"msg":"Package installed"}
      #  {"success":false,"msg":"no package"}
      output=$(curl -s -u admin:admin -F cmd=install "http://localhost:4503/crx/packmgr/service/.json/etc/packages/$packGroup/$packName")
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      if [ "$result" == "true" ]
        then
          echo LogSuccess: "Installed $packName" >> "${XPLR_PIPE_MSG_IN:?}"
        else
          echo LogError: "Failed to install $packName" >> "${XPLR_PIPE_MSG_IN:?}"
      fi
    else
      echo LogError: "Failed to install $packName" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local copyFilePath = commandMode.cmd("copy path", "Copy the path to a focused file into clipboard") (
        commandMode.BashExecSilently [===[
  echo "$XPLR_FOCUS_PATH" | perl -pe 'chomp if eof' | xclip -selection clipboard
  echo LogSuccess: "Copied a file path to the clipboard ($XPLR_FOCUS_PATH)" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local copyFileName = commandMode.cmd("copy name", "Copy the name of a focused file into clipboard") (
        commandMode.BashExecSilently [===[
  fileName=$(basename "$XPLR_FOCUS_PATH")
  echo "$fileName" | perl -pe 'chomp if eof' | xclip -selection clipboard
  echo LogSuccess: "Copied a file name to the clipboard ($fileName)" >> "${XPLR_PIPE_MSG_IN:?}"
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
  echo LogSuccess: "Opened the directory in IntelliJ IDEA - ${XPLR_FOCUS_PATH}" >> "${XPLR_PIPE_MSG_IN:?}"
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
