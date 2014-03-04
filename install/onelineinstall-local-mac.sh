#!/usr/bin/env bash
# Generated automatically at 2014-02-20 12:23:33.382164
#
SDK_ZIP_NAME=PebbleSDK-2.0.1.tar.gz
#
# variables set to be used by alexey locally,
# run `python -m SimpleHTTPServer` in ~/Downloads to make this useful.

PEBBLE_HOME="/Users/alexey/Dropbox/Code/PebbleSDKs"
SDK_URL="http://localhost:8000/PebbleSDK-latest.tar.gz"
ARMTOOLS_URL="http://localhost:8000/arm-cs-tools-macos-universal-static.tar.gz"

DEBUG=1
# This is the "actually do work" part of the script.
# TODO(AMK):
#  - include version of script in analytics / errors.
#  - General rewrite, realizing that you can use last command in if directly

# From the first part, the following variables are expected:
if [ ! $PEBBLE_HOME ] || [ ! $SDK_URL ] || [ ! $ARMTOOLS_URL ]
then
  echo "Missing variables (can't look up where to get the SDK)"
  exit 1
fi

SDK_NAME=$(echo $SDK_ZIP_NAME | rev | cut -d. -f3- | rev)
ARMTOOLS_ZIP_NAME=${ARMTOOLS_URL##*/}
ADD_PEBBLE_CMD_TO_PATH="export PATH=$PEBBLE_HOME/PebbleSDK-current/bin:\$PATH"
OSX_VERSION=$(sw_vers -productVersion)
# sample OSX_VERSION=10.8.4
PYTHON_VERSION=$(python -c 'import sys; print(str(sys.version_info[:])[1:-1].replace(" ", ""))')
PYTHON_MAJOR_VERSION=$(echo $PYTHON_VERSION | cut -d, -f1)
PYTHON_MINOR_VERSION=$(echo $PYTHON_VERSION | cut -d, -f2)
PYTHON2=$([ $PYTHON_MAJOR_VERSION == "2" ] && echo "python" || echo "python2")
INSTALL_LOG="$PEBBLE_HOME/install.log"
# sample PYTHON_VERSION=2,7,5

# colors
ESC_SEQ="\x1b["
COL_BLUE=$ESC_SEQ"34;01m"
COL_RED=$ESC_SEQ"31;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_RESET=$ESC_SEQ"39;49;00m"

_log()
{
  # at this point, we are in the SDK and we can run some amount of python2
  PEBBLE_BIN=$PEBBLE_HOME/$SDK_NAME/tools/pebble
  CAN_LOG=$(ls $PEBBLE_BIN &> /dev/null; echo $?)
  if $CAN_LOG
  then
    cd $PEBBLE_BIN
    EVENT_NAME="$@"
    PYTHON_DEBUG=$([ -n "$DEBUG" ] && echo "import logging; logging.basicConfig(level=logging.DEBUG);" || echo "")
    $PYTHON2 -c "import PblAnalytics; $PYTHON_DEBUG PblAnalytics._Analytics.get().post_event('install', 'onelinescript', '$EVENT_NAME')"
    cd -
  else
    echo "Wanted to log $EVENT_NAME, but couldn't (/bin/pebble not available yet)"
  fi
}

_echo()
{
  # separate function because it'll actually work even when we supress standard output
  echo "$@" >&3
}

_headline()
{
  echo "$COL_BLUE $@ $COL_RESET" >&3
  echo "" >&3
}

_warn()
{
  # use like > _warn broken_code "Hey some stuff broke dude"
  # or > _warn "yo some stuff broke but I have no code for you"
  REASON=$([ "$2" == "" ] && echo $1 || echo $2)
  if [ "$2" != "" ]
  then
    REASON_CODE=$1
    _log $REASON_CODE
  fi
  echo "$COL_YELLOW $REASON $COL_RESET" >&4
}

_fail()
{
  # use like > _fail nopython "You don't appear to have python installed..."
  REASON_CODE=$1
  REASON=$2
  _log $REASON_CODE
  echo "$COL_RED $REASON $COL_RESET" >&4
  echo
  echo "If you aren't sure how to remedy the issue, please send us your error log (at $INSTALL_LOG) to devsupport@getpebble.com, and we'll try to help!" >&4
  open "mailto:devsupport@getpebble.com?subject=Pebble SDK installation issues"
  exit 1
}

_fail_if_error()
{
  # if the last command failed (via $?) then call fail with same arguments
  if [ $? -ne 0 ]
  then
    _fail $1 "$2"
  fi
}

pebblesdk_preinstall()
{
  _headline "Preparing for Pebble Installation..."
  # 1. we officially support python 2.7
  if  ! hash python >/dev/null 2>&1;
  then
    _fail nopython "Python does not appear to be installed on this system.
Pebble SDK requires python 2.7"
  else
    if [ $PYTHON_MAJOR_VERSION == "3" ]
    then
      # the user has python3, but they might also have python2 installed, which makes it OK.
      if ! hash python2 >/dev/null 2>&1
      then
        _fail nopython2 "Python 2 does not appear to be installed on this system.
Pebble SDK requires python 2.7"
      fi
    # the user has python2 - let's make sure it's new enough.
    elif [ $PYTHON_MAJOR_VERSION != "2" ] || (( $PYTHON_MINOR_VERSION < "7" ))
    then
      _fail oldpython2 "Pebble SDK requires python 2.7 or later; please upgrade your Python version."
    fi
  fi

  # 2. check correct OSX version, xcode command line tools installed
  if [ $(echo $OSX_VERSION | cut -d. -f1) != "10" ] || (( $(echo $OSX_VERSION | cut -d. -f2) < "6" ))
  then
    _fail oldosx "Pebble SDK requires your Mac to have OSX 10.6 or newer"
  else
    # check for xcode
    xcode-select --print-path &>/dev/null
    if [ $? -ne 0 ]
    then
      # basically you have no xcode and this is a blocker.
      _warn "Your Mac is missing the XCode Command Line Tools, which are required "
      _warn "for the Pebble SDK (and most development tools)."
      _warn ""
      if (( $(echo $OSX_VERSION | cut -d. -f2) >= "9" ))
      then
        xcode-select --install
        _warn "You appear to have 10.9 (Mavericks) or newer"
        _warn "We have started the install (look for a pop-up, click Install XCode) and you may start"
        _warn "one yourself at any time by typing 'xcode-select --install' into your terminal."
        _warn ""
      elif (( $(echo $OSX_VERSION | cut -d. -f2) >= "7" ))
      then
        open https://itunes.apple.com/us/app/xcode/id497799835#
        _warn "In 10.7 or 10.8, your best bet is to install the tools from the Mac App Store"
        _warn "available at https://itunes.apple.com/us/app/xcode/id497799835 (opening)"
        _warn ""
        _warn "After installing, enable command line tools within XCode (see "
        _warn "http://pedrovanzella.com/blog/2012/03/13/installing-xcodes-command-line-tools-on-10-dot-7-3/"
        _warn "for an explanation)"
      elif [ $(echo $OSX_VERSION | cut -d. -f2) == "6" ]
      then
        open http://developer.apple.com/downloads
        _warn "For 10.6, your best bet is to download XCode 4.2 from the Apple Developer site,"
        _warn "available at http://developer.apple.com/downloads (opening)"
        _warn "an Apple Developer Account is required."
      else
        # we have no idea what version of xcode you have, at this point
        _warn "Unknown OS version - your best bet is to download XCode 4.2 from the Apple Developer site,"
        _warn "available at http://developer.apple.com/downloads (opening)"
        _warn "Note: Pebble SDK currently supports OS X 10.6 or newer"
      fi

      _warn ""
      _fail noxcode "Please re-run this script once you have the XCode Command Line Tools installed."
    fi
  fi

  # 3. Check that the command line tools, specifically, are installed (via clang)
  if ! hash clang >/dev/null 2>&1;
  then
    _fail no_xcode_commandlinetools "You have XCode, but not the XCode Command Line Tools, installed.
    To install the command-line tools, open XCode and go to
    XCode (menu bar) --> Preferences --> Downloads, and download the command line tools under
    Components.

    Once the command line tools are installed, re-run this command"
  fi


  # 4. OS X 10.6 specific issue with xcode 4.2
  if [ $(echo $OSX_VERSION | cut -d. -f2) == "6" ]
  then
    if ! hash gcc-4.2 >/dev/null 2>&1;
    then
      if hash llvm-gcc-4.2 >/dev/null 2>&1;
      then
        _warn "Your version of XCode does not properly name GCC 4.2.
    To fix this, we symlink 'llvm-gcc-42' to 'gcc-4.2'.

    Your sudo (admin) password will be required for this symlink."
        _echo "sudo ln -s /usr/bin/llvm-gcc-4.2 /usr/bin/gcc-4.2"
        sudo ln -s /usr/bin/llvm-gcc-4.2 /usr/bin/gcc-4.2 >&3 2>&4
        _fail_if_error couldnt_symlink_gcc "Symlinking GCC failed.
  Please ensure that gcc-4.2 is available on this machine and run this script again."
      else
        _fail cant_find_gcc42 "Couldn't find gcc-4.2, which is required for this install.
  Please ensure that gcc-4.2 is available on this machine and run this script again."
      fi
    fi
  fi

  # 5. agree to xcode terms, on command line (at least 10.9)
  # 69 = you haven't agreed to terms yet.
  if [ $(xcodebuild >/dev/null 2>&1; echo $?) == "69" ]
  then
    _warn "You have installed XCode, but not yet acceped the terms of service.
Please accept them below (will require sudo)."
    sudo xcodebuild >&3 2>&4
    if [ $(xcodebuild >/dev/null 2>&1; echo $?) == "69" ]
    then
      _fail couldnt_accept_xcode_terms "Please accept the XCode terms of service manually
by launching XCode and going through the process"
    fi
  fi

}

pebblesdk_download()
{
  _headline "Downloading SDK"
  cd $PEBBLE_HOME
  curl -fSL $SDK_URL --remote-name
  _fail_if_error no_sdk_download "Couldn't download SDK from $SDK_URL."
  # TODO(AMK): arm tools should either be integrated or stored somewhere on the system and then symlinked
  # to make the update case faster
  curl -fSL $ARMTOOLS_URL --remote-name
  _fail_if_error no_armtools_download "Couldn't download ARM TOOLS from $ARMTOOLS_URL."
}

pebblesdk_unzip()
{
  _headline "Extracting SDK"
  cd $PEBBLE_HOME
  # if the name of the .tar.gz != name of the folder inside, extraction happens into a different folder.
  # Workaround: --strip-components. Yup, I know. http://xkcd.com/1168/
  rm -r $SDK_NAME
  # it's OK for this to fail if the OLD SDK isn't there
  mkdir $SDK_NAME
  _fail_if_error couldnt_unzip_sdk_mkdir "Couldn't create folder for SDK to unzip into $SDK_NAME"
  tar -zxf $SDK_ZIP_NAME --strip-components=1 -C $SDK_NAME
  _fail_if_error couldnt_unzip_sdk_tar "Couldn't unzip SDK from $SDK_ZIP_NAME"
  tar -zxf $ARMTOOLS_ZIP_NAME -C $SDK_NAME
  _fail_if_error couldnt_unzip_tools "Couldn't unzip arm tools into $SDK_NAME"

  chmod a+x $SDK_NAME/bin/pebble
  _fail_if_error temp_could_add_exec "Couldn't add execute permissions to /bin/pebble $SDK_NAME"
}

pebblesdk_pythoninstall()
{
  _headline "Installing Python Dependencies"
  # TODO(AMK): python 2 vs python3
  if ! hash pip >/dev/null 2>&1;
  then
    _warn "It appears this machine does not yet have pip, the python package installer
Installing it for you now.  This will require your admin password (for sudo)."
    # Installing from github and not from easy_install. Here's why:
    # If the user has python 2.6 and 2.7, easy_install might be tied to the wrong python version
    # and then we'd have the wrong pip, and it all goes downhill from there.
    curl -sSL https://raw.github.com/pypa/pip/master/contrib/get-pip.py > /tmp/get-pip.py
    _echo "sudo python /tmp/get-pip.py"
    sudo python /tmp/get-pip.py >&3 2>&4
    _fail_if_error couldnt_install_pip "We were unable to install pip on your system.
Please install pip manually and try again."
  fi

  if ! hash virtualenv >/dev/null 2>&1
  then
    _warn "It appears this machine does not yet have virtualenv,
the virtual environment manager for python.  Installing it for you now.
This will require your admin password (for sudo)."
    _echo "sudo pip install virtualenv"
    sudo pip install virtualenv >&3 2>&4
    _fail_if_error couldnt_install_virtualenv "We were unable to install
    virtualenv on your system. Please install virtualenv and try again"
  fi

  OLD_PATH=$(pwd)
  cd $PEBBLE_HOME/$SDK_NAME
  virtualenv --no-site-packages .env
  _fail_if_error virtualenv_create_failed "We were unable to create a new virtual environment."

  source .env/bin/activate

  # arch flags are useful for PIL for OS X 10.6 with GCC
  # http://stackoverflow.com/questions/5366882/installing-pil-on-os-x-snow-leopard-w-xcode4-no-ppc-support
  ARCHFLAGS="-arch i386 -arch x86_64" pip install -r requirements.txt
  _fail_if_error pip_install_failed "We were unable to use pip to install the python pre-requisites on your system.
  Please try to manually use pip to install the dependencies in requirements.txt and try again"

  deactivate

  cd $OLD_PATH
}

pebblesdk_pebblecommand()
{
  _headline "Installing 'pebble' command"
  # always symlink the latest install into "current"
  cd $PEBBLE_HOME
  rm -r ./PebbleSDK-current
  ln -s $SDK_NAME ./PebbleSDK-current

  # Mac-specific: warn if custom shell
  if [[ $(dscl . -read ~ UserShell) != "UserShell: /bin/bash" ]]
  then
    CUSTOM_SHELL_WARNING=1
  else
    # if bash profile exists, source it (so we find pebble command)
    head ~/.bash_profile > /dev/null && source ~/.bash_profile

    # install in ~/.bash_profile unless already there
    if ! hash pebble >/dev/null 2>&1
    then
      _echo "adding 'pebble' command to bash profile"
      # TODO(AMK): a version that doesn't force the user to use bash_profile
      # add line to bash_profile
      echo "" >> ~/.bash_profile
      echo "# Pebble SDK" >> ~/.bash_profile
      echo $ADD_PEBBLE_CMD_TO_PATH >> ~/.bash_profile
      if [ $? -ne 0 ]
      then
        _warn couldntadd_bashprofile "Warning: Couldn't save pebble command into ~/.bash_profile"
        CUSTOM_SHELL_WARNING=1
      fi
    else
      _echo "'pebble' command already installed"
      _echo ""
    fi
  fi

  # note: sourcing pebble only applies to the currently running shell,
  # so you still want to source bash_profile once this script is done for testing
  eval $ADD_PEBBLE_CMD_TO_PATH
  _fail_if_error cant_add_pebble_to_path "Couldn't add the pebble command to path"
}

pebblesdk_test()
{
  _headline "Building Test Pebble Project"
  # create and then try to build a new project, ensure it compiles
  eval $ADD_PEBBLE_CMD_TO_PATH
  rm -r install_test 2> /dev/null
  pebble new-project install_test
  _fail_if_error buildtest_fail_newproject "Couldn't create a test project."
  CUR_DIR=$(pwd)
  cd install_test
  BUILD_RESULT=$(pebble build 2>&1 >/dev/null | tail -n 1)
  if [[ $BUILD_RESULT == "'build' finished successfully"* ]]
  then
    _log buildtest_pass
    _echo "Building sample app: success."
  else
    _warn buildtest_fail "Build failed, we should look into this
    Failure reason: $(pebble build 2>&1 | tail)"
  fi

  cd $CUR_DIR
  rm -r install_test
}

pebblesdk_report()
{
  _echo "$COL_GREEN"
  _echo "========================================================"
  _echo "Results:"
  _echo "========================================================"
  _echo "Install of $SDK_NAME into $PEBBLE_HOME was successful!"
  _echo "$COL_RESET"

  if [ $CUSTOM_SHELL_WARNING ]
  then
    _warn "You are using a non-standard shell (IE, not bash)."
    _warn ""
    _warn "To get the 'pebble' command into your path, you'll need to add $PEBBLE_HOME/PebbleSDK-current/bin to your \$PATH."
    _warn ""
    _warn " For reference: with bash, we would have done this by typing "
    _warn " echo export PATH='$PEBBLE_HOME/PebbleSDK-current/bin:\$PATH' >> ~/.bash_profile "
    _log customshell_warning
  fi
}

pebblesdk_install()
{
  # Invariant: none of these functions should make any assumptions
  # about the directory they start in
  echo "Starting install at $(date)"
  ORIG_DIR=$(pwd)
  pebblesdk_preinstall
  pebblesdk_download
  pebblesdk_unzip
  pebblesdk_pythoninstall
  pebblesdk_pebblecommand
  # TODO(AMK): Pebble SDK fonts
  pebblesdk_test
  pebblesdk_report
  echo "Install finished at $(date)"
  cd $ORIG_DIR
}


# make SDK dir, if it didn't exist before
# needs to happen really early b/c otherwise redirection for stdout breaks
if [ ! -d $PEBBLE_HOME ]
then
  mkdir -p $PEBBLE_HOME
  _fail_if_error couldnt_make_sdkdir "Could not create $PEBBLE_HOME directory.
  Please create the directory, ensure you are able to write to it, and try again."
fi

if [ -n "$DEBUG" ] && [ ! $USE_PEBBLE_LOG ]
then
  pebblesdk_install "$@" 3>&1 4>&2
else
  # Don't show normal users how the hot dog is made during the install. To do that:
  # if you're in prod mode, write normal output to log
  # use streams 3/4 for things we actually want in stdout/stderr
  touch $INSTALL_LOG
  pebblesdk_install "$@" 3>&1 4>&2 1>>$INSTALL_LOG 2>>$INSTALL_LOG
fi
