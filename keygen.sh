#!/bin/bash
# https://stackoverflow.com/questions/43235179/how-to-execute-ssh-keygen-without-prompt
ssh-keygen -q -t rsa -N '' <<< ""$'\n'"y" 2>&1 >/dev/null
