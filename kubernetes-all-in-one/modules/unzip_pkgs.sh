#!/bin/bash
#===============================================================================
#          FILE: unzip_pkgs.sh
#         USAGE: . ${YOUR_PATH}/unzip_pkgs.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-28 17:03:22
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

# Unzip packages.
[ -d temp ] && rm -rf temp && mkdir temp
[ ! -d temp ] && mkdir temp
for pkg in `ls pkgs/*.tar.gz`;
  do
    tar -xvzf ${pkg} -C temp/
  done
