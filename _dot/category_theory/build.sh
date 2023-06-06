#! /bin/bash


shopt -s globstar


function build {
    echo $1
    dss --style style.dss --input $1 | dot -Tpng > ../../img/category/$1.png
    optipng ../../img/category/$1.png
}

mkdir -p ../../img/category
for file in ./**/*.dot ; do
    build $file
done;
