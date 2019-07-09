for flanneld_node in ${hosts[@]}
  do
   if [ ${flanneld_node} != ${hosts['gysl-master']} ];then
    rm -rf ${flanneld_conf} && mkdir -p ${flanneld_conf}
   fi
  done