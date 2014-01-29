#!/bin/bash

# This base image is small but they used the Brazillian Ubuntu archive mirror for some reason.
sed -i 's/br\.//g' /etc/apt/sources.list
