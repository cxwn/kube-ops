#!/bin/bash
#===============================================================================
#          FILE: kube_install.sh
#         USAGE: . ${YOUR_PATH}/kube_install.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-05-16 17:05:26
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh
while true;
   do
   getenforce
