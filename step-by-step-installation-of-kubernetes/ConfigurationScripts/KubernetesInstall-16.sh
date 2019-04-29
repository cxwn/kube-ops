#!/bin/bash
CSRS=$(kubectl get csr | awk '{if(NR>1) print $1}')
for csr in $CSRS;
    do
        kubectl certificate approve $csr;
    done