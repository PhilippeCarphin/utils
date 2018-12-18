#!/bin/bash
################################################################################
#
# This file would have been a fish function
#
# function profile
#     profile_files="~/.philconfig/config/fish/conf.d/omf.fish ~/.philconfig/envvars.fish"
#     ec -t $profile_files
#     exec fish
# end
#
# however the call to exec during the function call caused a warning
# because the currently executing function was seen as an active job
# by fish.
################################################################################

profile_files="~/.philconfig/config/fish/conf.d/omf.fish ~/.philconfig/envvars.fish"
ec -t $profile_files
exec fish
