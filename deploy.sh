#!/bin/bash

git_uri="$1"
sources_branch="sources"
docs_branch="gh-pages"

set -o errexit
shopt -s globstar

# Change to script's directory
cd "$(dirname "$0")"

mkdir build || true
pushd build
    cmake ..
    make
popd

if [ ! -d deploy ]; then
    # Clone the specified repository or just make a folder for the results
    if [ -n "$git_uri" ]; then
        git clone -b "$sources_branch" -- "$git_uri" deploy
    else
        mkdir deploy
    fi
fi

rm -r -- deploy/* 2>/dev/null || true

cp --parents --no-dereference -- $(git ls-files) deploy/
rm -- deploy/* deploy/.* deploy/src/README.md deploy/**/*.in 2>/dev/null || true
cp README.md LICENSE logo.png deploy/

pushd build
    cp --parents -- src/**/*.cr voidcsfml/include/**/*.h voidcsfml/src/**/*.cpp shard.yml voidcsfml/CMakeLists.txt ../deploy/
popd

# Get current git commit's hash
rev="$(git rev-parse HEAD)"

pushd deploy
    if [ -n "$git_uri" ]; then
        git config user.name 'Robot'
        git config user.email '<>'

        # If version changes in the shard file, make a corresponding tag
        new_tag="$(git diff -- shard.yml | grep -P --only-matching "(?<=\+version: )[0-9\.]+$")" || true

        git add -A
        if git commit -m "Generate sources ($rev)"; then
            if [ -n "$new_tag" ]; then
                git tag "v$new_tag"
            fi
            git push --tags origin "$sources_branch" >/dev/null 2>&1
        fi

        rev="$(git rev-parse HEAD)"
    fi

    crystal doc

    logo="https://raw.githubusercontent.com/BlaXpirit/crsfml/$sources_branch/logo.png"
    logo='<a href="https://github.com/BlaXpirit/crsfml#readme"><img src="'"$logo"'" alt="CrSFML" height="64"/></a>'
    # Replace README link with CrSFML
    find doc/ -type f -exec sed -i -r -e "s,<a.+>README</a>,$logo," {} \;

    # Expand current node
    find doc/ -type f -exec sed -i -r -e 's,parent current,parent current open,' {} \;

    # Redirect from / to /SF.html
    cat << EOF > doc/index.html
<!DOCTYPE HTML>
<html>
<head>
    <meta http-equiv="refresh" content="1;url=SF.html"/>
    <title>Redirecting...</title>
    <script type="text/javascript">
        window.location.href = "SF.html";
    </script>
</head>
<body>
    <a href="SF.html">Redirecting...</a>
</body>
</html>
EOF

    if [ -n "$git_uri" ]; then
        if [ -n "$new_tag" ]; then
            # Replace commit name with tag name in links
            find doc -type f -exec sed -i -r -e "s,blob/$rev,blob/v$new_tag,g" {} \;
        fi

        git checkout "$docs_branch"

        rm -r api || true
        mv doc api

        git add -A
        if git commit -m "Generate API documentation ($rev)"; then
            git push origin "$docs_branch" >/dev/null 2>&1
        fi

        git checkout "$sources_branch"
    fi