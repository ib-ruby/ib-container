#!/bin/bash
rvm use 3
cd simple-monitor
bundle install
bundle update
cp tmux.conf /home/ubuntu/.tmux.conf
mkdir /home/ubuntu/.elinks
cp elinks.conf /home/ubuntu/.elinks/elinks.conf


