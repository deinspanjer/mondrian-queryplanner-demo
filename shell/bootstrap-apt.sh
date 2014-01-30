#!/bin/bash

# This base image is small but they used the Brazillian Ubuntu archive mirror for some reason.
sed -i 's/br\.//g' /etc/apt/sources.list


# Git rid of the "stdin is not a tty" errors
sed -i 's/^mesg n$/tty -s \&\& mesg n/g' /root/.profile


# Debugging info
#grep 'printenv' /etc/profile || echo "printenv | grep '^\(SUDO_[^=]*\|USER\|HOME\|\(JAVA\|TAJO\|HADOOP\)_HOME\)='" >> /etc/profile
