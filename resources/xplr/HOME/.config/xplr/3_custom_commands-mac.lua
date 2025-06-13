-- 3_custom_commands
local deployToAEMAuthor = commandMode.cmd("aem deploy author", "Upload and install a content package to AEM Author instance running at http://localhost:4502") (
        commandMode.BashExec [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  echo "Testing the archive validity..."
  unzip -t "$XPLR_FOCUS_PATH"
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

      echo "Disabling WorkflowLauncherImpl..."
      curl --user admin:admin 'http://localhost:4502/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherImpl' --data 'action=disable'
      echo ""
      echo "Disabling WorkflowLauncherListener..."
      curl --user admin:admin 'http://localhost:4502/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherListener' --data 'action=disable'

      output=$(curl --verbose --user admin:admin -F file=@"$XPLR_FOCUS_PATH" -F name="$baseName" -F force=true -F recursive=true -F install=true http://localhost:4502/crx/packmgr/service.jsp | tee >(cat >&2))
      result=$(echo "$output" | grep -c 'Package imported\|Package installed\|<status code="200">ok</status>')

      echo "Enabling WorkflowLauncherImpl..."
      curl --user admin:admin 'http://localhost:4502/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherImpl' --data 'action=enable'
      echo ""
      echo "Enabling WorkflowLauncherListener..."
      curl --user admin:admin 'http://localhost:4502/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherListener' --data 'action=enable'

      echo ""
      echo "Press ENTER to continue..."
      read voidInput
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
        commandMode.BashExec [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  echo "Testing the archive validity..."
  unzip -t "$XPLR_FOCUS_PATH"
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

      echo "Disabling WorkflowLauncherImpl..."
      curl --user admin:admin 'http://localhost:4503/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherImpl' --data 'action=disable'
      echo ""
      echo "Disabling WorkflowLauncherListener..."
      curl --user admin:admin 'http://localhost:4503/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherListener' --data 'action=disable'

      output=$(curl --verbose --user admin:admin -F file=@"$XPLR_FOCUS_PATH" -F name="$baseName" -F force=true -F recursive=true -F install=true http://localhost:4503/crx/packmgr/service.jsp | tee >(cat >&2))
      result=$(echo "$output" | grep -c 'Package imported\|Package installed\|<status code="200">ok</status>')

      echo "Enabling WorkflowLauncherImpl..."
      curl --user admin:admin 'http://localhost:4503/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherImpl' --data 'action=enable'
      echo ""
      echo "Enabling WorkflowLauncherListener..."
      curl --user admin:admin 'http://localhost:4503/system/console/components/com.adobe.granite.workflow.core.launcher.WorkflowLauncherListener' --data 'action=enable'

      echo ""
      echo "Press ENTER to continue..."
      read voidInput
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

local uploadPackToAEMAuthor = commandMode.cmd("aem upload author", "Upload a content package to AEM Author instance running at http://localhost:4502") (
        commandMode.BashExec [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  echo "Testing the archive validity..."
  unzip -t "$XPLR_FOCUS_PATH"
  exitCode=$?
  if [ "$exitCode" == 0 ]
    then
      # Might produce results like:
      #  {"success":true,"msg":"Package uploaded","path":"/etc/packages/my_packages/UNIVERSE.zip"}
      #  {"success":false,"msg":"Zip File is not a content package. Missing 'jcr_root'."}
      #  curl: (7) Failed to connect to localhost port 4502 after 0 ms: Connection refused
      output=$(curl --verbose --user admin:admin -F cmd=upload -F force=true -F package=@"$XPLR_FOCUS_PATH" http://localhost:4502/crx/packmgr/service/.json | tee >(cat >&2))
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      echo ""
      echo "Press ENTER to continue..."
      read voidInput
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
        commandMode.BashExec [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  echo "Testing the archive validity..."
  unzip -t "$XPLR_FOCUS_PATH"
  exitCode=$?
  if [ "$exitCode" == 0 ]
    then
      # Might produce results like:
      #  {"success":true,"msg":"Package uploaded","path":"/etc/packages/my_packages/UNIVERSE.zip"}
      #  {"success":false,"msg":"Zip File is not a content package. Missing 'jcr_root'."}
      #  curl: (7) Failed to connect to localhost port 4503 after 0 ms: Connection refused
      output=$(curl --verbose --user admin:admin -F cmd=upload -F force=true -F package=@"$XPLR_FOCUS_PATH" http://localhost:4503/crx/packmgr/service/.json | tee >(cat >&2))
      result=$(echo "$output" | cut -d : -f 2 | cut -d , -f 1)
      echo ""
      echo "Press ENTER to continue..."
      read voidInput
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

local catContent = commandMode.cmd("cat content", "Show content of a focused file with cat") (
        commandMode.BashExec [===[
  fileName=$(basename "$XPLR_FOCUS_PATH")
  if [ -d "$fileName" ]
    then
      echo LogError: "${fileName} is a directory. Operation aborted" >> "${XPLR_PIPE_MSG_IN:?}"
    else
      cat "$fileName" | less
      echo LogSuccess: "Content of $fileName presented" >> "${XPLR_PIPE_MSG_IN:?}"
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
      cat "$fileName" | perl -pe 'chomp if eof' | pbcopy
      echo LogSuccess: "Copied content of $fileName into clipboard" >> "${XPLR_PIPE_MSG_IN:?}"
  fi
  ]===]
)

local copyItemName = commandMode.cmd("copy name", "Copy the name of a focused item into clipboard") (
        commandMode.BashExecSilently [===[
  fileName=$(basename "$XPLR_FOCUS_PATH")
  echo "$fileName" | perl -pe 'chomp if eof' | pbcopy
  echo LogSuccess: "Copied an item name to the clipboard∶ $fileName" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local copyItemPath = commandMode.cmd("copy path", "Copy the path to a focused item into clipboard") (
        commandMode.BashExecSilently [===[
  echo "$XPLR_FOCUS_PATH" | perl -pe 'chomp if eof' | pbcopy
  echo LogSuccess: "Copied an item path to the clipboard∶ $XPLR_FOCUS_PATH" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local decompile = commandMode.cmd("decompile", "Decompile a focused item (normally .jar, .zip or .class file) to a current location") (
        commandMode.BashExec [===[
    fernflowerJar="$HOME/.local/share/java/fernflower/fernflower.jar"
    baseName=$(basename -- "$XPLR_FOCUS_PATH")

    generateTargetFolder() {
      echo "${dirNameForFile}/${baseName}_${RANDOM}"
    }

    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk use java 21.0.3-tem
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
      echo "[Press Enter to continue]"
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
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  launcherPath="/opt/homebrew/bin/idea-ce"

  if [ ! -f "$launcherPath" ]
    then
      echo LogError: "The IntelliJ IDEA launcher hasn't been detected" >> "${XPLR_PIPE_MSG_IN:?}"
      exit 0 # This code must be 0. Otherwise, the above error will not be logged by xplr
  fi

  if [ ! -d "$XPLR_FOCUS_PATH" ]
    then
      echo LogError: "The directory ${XPLR_FOCUS_PATH} doesn't exist" >> "${XPLR_PIPE_MSG_IN:?}"
      exit 0 # This code must be 0. Otherwise, the above error will not be logged by xplr
  fi
  nohup "$launcherPath" nosplash "$XPLR_FOCUS_PATH" > /dev/null 2>&1 &
  echo LogSuccess: "Opened the directory in IntelliJ IDEA∶ $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local nvim = commandMode.cmd("nvim", "Open a focused text file in NeoVim") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  fileType=$(file "$XPLR_FOCUS_PATH" | cut -d ' ' -f 2-)
  fileTypeLowerCase=$(echo "$fileType" | tr '[:upper:]' '[:lower:]')

  if [[ "$fileTypeLowerCase" == *"text"*
     || "$fileTypeLowerCase" == *"json"* ]];
    then
      # On Apple Script:
      #   1. https://apple.stackexchange.com/a/335779
      #   2. https://stackoverflow.com/questions/56862644/open-iterm2-from-bash-script-run-commands#comment105229692_56862822
      #   3. https://stackoverflow.com/a/29260286
      osascript -e '
      on run argv
        if application "iTerm" is not running then
          activate application "iTerm"
        else
          tell application "iTerm"
            create window with default profile
            activate
            tell current session of current window
              write text "nvim " & quoted form of (item 1 of argv)
            end tell
          end tell
        end if
      end run' "$XPLR_FOCUS_PATH"
      echo LogSuccess: "Opened '${baseName}' in NeoVim" >> "${XPLR_PIPE_MSG_IN:?}"
  else
      echo LogError: "Is not a valid text file∶ $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      exit 0 # This code must be 0. Otherwise, the above error will not be logged by xplr
  fi
  ]===]
)

local pdf = commandMode.cmd("pdf", "Open a focused pdf file in Microsoft Edge") (
        commandMode.BashExecSilently [===[
  # TODO: change to Edge
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  fileType=$(file --brief "$XPLR_FOCUS_PATH")
  fileTypeLowerCase=$(echo "$fileType" | tr '[:upper:]' '[:lower:]')
  edgeLauncher="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"

  if [[ "$fileTypeLowerCase" == *"pdf"* ]];
    then
      "$edgeLauncher" "$XPLR_FOCUS_PATH" &> /dev/null
      echo LogSuccess: "Opened '${baseName}' in Google Chrome" >> "${XPLR_PIPE_MSG_IN:?}"
  else
      echo LogError: "Is not a valid pdf file∶ $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
      exit 0 # This code must be 0. Otherwise, the above error will not be logged by xplr
  fi
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
  numOfRecursiveItemsInDirectory=$(find "$XPLR_FOCUS_PATH" -mindepth 1 | wc -l | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  
  echo LogSuccess: "${baseName}∶ $dirSize | $numOfRecursiveItemsInDirectory item(s) recursively" >> "${XPLR_PIPE_MSG_IN:?}"
  ]===]
)

local unarchive = commandMode.cmd("unarchive", "Unzip/untar/unjar a focused file to a current location") (
        commandMode.BashExec [===[
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
    echo "Testing the archive with unzip..."
    unzip -t "$XPLR_FOCUS_PATH"
    exitCode=$?
    if [ "$exitCode" == 0 ]
      then
        mkdirForTargetPath
        echo "Unzipping the archive with unzip..."
        yes | unzip "$XPLR_FOCUS_PATH" -d "$targetPath"
        finishWithSuccess
      else
        # 2. Test with gzip
        echo "Testing the archive with gzip..."
        gzip -t "$XPLR_FOCUS_PATH"
        exitCode=$?

        # 3. Test with tar (possible only by listing a tar archive content)
        if [ "$exitCode" != 0 ]
          then
            echo "Testing the archive with tar..."
            tar -tf "$XPLR_FOCUS_PATH"
            exitCode=$?
        fi

        if [ "$exitCode" == 0 ]
          then
            mkdirForTargetPath
            echo "Unzipping the archive with tar..."
            tar -xf "$XPLR_FOCUS_PATH" --directory "$targetPath"
            finishWithSuccess
          else
            # 4. Test with 7z
            echo "Testing the archive with 7z..."
            7z t "$XPLR_FOCUS_PATH"
            exitCode=$?
            if [ "$exitCode" == 0 ]
              then
                mkdirForTargetPath
                echo "Unzipping the archive with 7z..."
                7z x -o"$targetPath" "$XPLR_FOCUS_PATH"
                finishWithSuccess
              else
                echo LogError: "Invalid source archive. Aborted" >> "${XPLR_PIPE_MSG_IN:?}"
            fi
        fi
    fi
  ]===]
)
