#!/bin/bash

export OLD_REPO=$1
export NEW_REPO=$2
shift
shift

if [ -z "$OLD_REPO" ] || [ -z "$NEW_REPO" ]
then
    echo "Usage: $0 OLD_REPO NEW_REPO"
    echo "Example: $0 git@github.com:myrealuser/xyz.git git@github.com:newuser/abc.git"
    exit 0
fi

export N=$(echo $OLD_REPO | perl -n -e 's/^.*?[:]//gm; s/\.git$//gm; $_=lc; s/_/-/gm; s/\//_/gm; s/[^a-z0-9-_]//gm; print')

export TMP=$HOME/.cache/github-copy-anonymous
mkdir -p $TMP
cd $TMP

test -f .bfg/bfg.jar || (
    mkdir -p .bfg
    wget http://repo1.maven.org/maven2/com/madgag/bfg/1.12.15/bfg-1.12.15.jar -O .bfg/bfg.jar
)

test -d $N || git clone --mirror "$OLD_REPO" $N
test -d $N || exit 1
(cd $N; git fetch --all;)
mkdir -p $N.tmp
rsync -av --delete $N/ $N.tmp/ && cd $N.tmp && (

    echo
    echo "Original Authors:"
    echo "-----------------"
    git log --pretty=full | perl -n -e 'if (/(Author|Commit): (.*?)\s*$/) { print $2."\n" }' | sort | uniq
    echo

    git filter-branch --env-filter '
        case "$GIT_AUTHOR_EMAIL" in
            *yandex.ru*)
                true # do nothing
            ;;
            *.ua)
                true # do nothing
            ;;
            *gitter.im)
                true # do nothing
            ;;
            *)
                export GIT_AUTHOR_NAME=$(echo "$GIT_AUTHOR_NAME" | sha512sum | sha512sum | cut -c1-10 | awk "{ print \$1 }");
                export GIT_AUTHOR_EMAIL=$(echo "$GIT_AUTHOR_EMAIL" | sha512sum | sha512sum | cut -c1-30 | awk "{ print \$1 }")@$(echo "$GIT_COMMITTER_EMAIL" | sha512sum | sha512sum | cut -c31-40 | awk "{ print \$1 }").$(echo "$GIT_COMMITTER_EMAIL" | sha512sum | sha512sum | cut -c41-44 | awk "{ print \$1 }");
                export GIT_COMMITTER_NAME=$(echo "$GIT_COMMITTER_NAME" | sha512sum | sha512sum | cut -c1-10 | awk "{ print \$1 }");
                export GIT_COMMITTER_EMAIL=$(echo "$GIT_COMMITTER_EMAIL" | sha512sum | sha512sum | cut -c1-30 | awk "{ print \$1 }")@$(echo "$GIT_COMMITTER_EMAIL" | sha512sum | sha512sum | cut -c31-40 | awk "{ print \$1 }").$(echo "$GIT_COMMITTER_EMAIL" | sha512sum | sha512sum | cut -c41-44 | awk "{ print \$1 }");
            ;;
        esac;
true;
    ' --tag-name-filter cat -f -- --all || (git status; exit 1)

    rm -rf .git/refs/original/

    git filter-branch -f --msg-filter \
    'perl -n -e "s/(github.com)[^ ]+($|\s)/\$1 /gm; print"' \
    --tag-name-filter cat -- --all

    # java -jar $TMP/.bfg/bfg.jar --strip-blobs-bigger-than 1M
    java -jar $TMP/.bfg/bfg.jar --delete-files '*.{jpg,png,mp4,m4v,ogv,webm}'

    rm -rf .git/refs/original/
    git pack-refs --all --prune
    git reflog expire --expire=now --all
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive

    echo
    echo "Anonymized Authors:"
    echo "-----------------"
    git log --pretty=full | perl -n -e 'if (/(Author|Commit): (.*?)\s*$/) { print $2."\n" }' | sort | uniq
    echo

    git remote set-url origin "$NEW_REPO"
    git push -f --mirror

)

echo $N

exit 0

if [ "
