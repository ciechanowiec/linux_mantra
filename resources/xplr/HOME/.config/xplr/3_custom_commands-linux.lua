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
    fernflowerJar="$HOME/.local/share/java/fernflower/fernflower.jar"
    baseName=$(basename -- "$XPLR_FOCUS_PATH")

    generateTargetFolder() {
      echo "${dirNameForFile}/${baseName}_${RANDOM}"
    }

    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk use java 17.0.8-tem # fernflower requires at least Java 17
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

local nvim = commandMode.cmd("nvim", "Open a focused text file in NeoVim") (
        commandMode.BashExecSilently [===[
  baseName=$(basename -- "$XPLR_FOCUS_PATH")
  fileType=$(file "$XPLR_FOCUS_PATH" | cut -d ' ' -f 2-)
  fileTypeLowerCase=$(echo "$fileType" | tr '[:upper:]' '[:lower:]')

  if [[ "$fileTypeLowerCase" == *"text"*
     || "$fileTypeLowerCase" == *"json"* ]];
    then
      gnome-terminal -- bash -c "nvim $XPLR_FOCUS_PATH"
      echo LogSuccess: "Opened '${baseName}' in NeoVim" >> "${XPLR_PIPE_MSG_IN:?}"
  else
      echo LogError: "Is not a valid text file∶ $baseName" >> "${XPLR_PIPE_MSG_IN:?}"
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
  numOfRecursiveItemsInDirectory=$(find "$XPLR_FOCUS_PATH" -mindepth 1 | wc -l)

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
