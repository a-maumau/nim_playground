#!/bin/sh

dir_list=$(ls -d */)

echo "building: "
echo $dir_list

for entry in $dir_list
do
    cd $entry
    make
    cd ../
    #echo "$entry"
done
