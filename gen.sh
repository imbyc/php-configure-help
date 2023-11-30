#!/usr/bin/env bash
set -Eeuo pipefail

. public.sh

# Modify From https://github.com/docker-library/php/blob/64811791f0682262478d73514819908fcfe73d7f/versions.sh

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=("$@")

if [ ${#versions[@]} -eq 0 ]; then
  # 不传入版本号，默认8 大版本号 可以 7 8 传入多个版本号
  versions=(8)
fi
versions=("${versions[@]%/}")

releasesPossibles=()
rcPossibles=()
addVersions=()

GetReleases() {
  # version 支持主版本号（5）、次版本号（5.2）、具体版本号（5.2.17）
  # 老版本有一些没有sha256,只有md5,甚至没有md5
  # 少量source下面不存在filename字段，如5.5.2,用 has 过滤一下
  # 老版本下载地址 https://museum.php.net/php5/php-5.1.2.tar.gz
  apiUrl="https://www.php.net/releases/index.php?json&max=200&version=${1}"
  apiJqExpr='
      include "version-id";
			(keys[] | select( version_id >= (env.startVersion|version_id) )) as $version
      | (.[$version].museum // false) as $museum | [
			$version,
			(
			  .[$version].source[]
				| select(has("filename"))
				| select(.filename | endswith(".gz"))
				|
					download_url($version ; $museum) + .filename,
					download_url($version ; $museum) + .filename + ".asc",
					.sha256 // "",
					.md5 // ""
			),
			.[$version].date // ""
			 ]
		'
  IFS=$'\n'
  releasesPossibles=($(
    curl -fsSL "$apiUrl" |
      jq --raw-output "$apiJqExpr | @sh" |
      sort -rV
  ))
  unset IFS
}

GetRC() {
  apiUrl='https://qa.php.net/api.php?type=qa-releases&format=json'
  apiJqExpr='
			(.releases // [])[]
			| select(.version | startswith(env.startVersion))
			| [
				.version,
				.files.gz.path // "",
				"",
				.files.gz.sha256 // "",
				"",
				.date // ""
			]
		'
  IFS=$'\n'
  curl -fsSL "$apiUrl" |jq --raw-output "(.releases // [])[]"
  rcPossibles=($(
    curl -fsSL "$apiUrl" |
      jq --raw-output "$apiJqExpr | @sh" |
      sort -rV
  ))
  unset IFS
}

# 如果 majorVersion = version 表示传进来的是主版本号，如 8 查找所有8开头的版本，8.0.1,8.0.2,8.0.4RC1,8.1.2，等等,RC版本也要找
# 如果 minorVersion = version 表示传进来的是次版本号，如 8.0 查找8.0开头的版本，8.0.1,8.0.2,RC版本也要找, 不会查找8.1.2
# version 不等于 majorVersion 和 minorVersion 就是具体版本号了，如8.0.3 或 8.0.4RC1 那就专找8.0.3 或 8.0.4RC1 版本
# 如果 version = cleanVersion 表示这不是一个RC版本,就从 releases 接口中找
# 不相等就是RC版本了，就从rc版本接口中找

# 什么参数都不传，默认 5 7 8 版本

for version in "${versions[@]}"; do

  # version=8.0.4-rc
  cleanVersion="${version%-rc}"      # 8.0.4 去除了-rc
  majorVersion="${cleanVersion%%.*}" # 8
  minorVersion="${cleanVersion%.*}"  # 8.0
  # 如果此时 majorVersion = minorVersion 说明实际传的就是一个次版本号
  [ "$majorVersion" = "$minorVersion" ] && minorVersion="${cleanVersion}"

  _info "version: $version cleanVersion: $cleanVersion majorVersion: $majorVersion minorVersion: $minorVersion "

  startVersion=${cleanVersion}

  export version majorVersion minorVersion cleanVersion startVersion

  if [ "$version" = "$majorVersion" ] || [ "$version" = "$minorVersion" ]; then
    # majorVersion = version 时如果传进来的是大版本为5,跳过5.6以下的低版本
    if [ "$version" = "$majorVersion" ] && [ $version = "5" ]; then
      startVersion="5.6.0"
    fi
    #GetReleases ${cleanVersion}
    GetRC
  elif [ "$version" = "$cleanVersion" ]; then
    GetReleases ${cleanVersion}
  else
    GetRC
  fi

  possibles=()
  [ ! ${#releasesPossibles[@]} -eq 0 ] && possibles+=("${releasesPossibles[@]}")
  [ ! ${#rcPossibles[@]} -eq 0 ] && possibles+=("${rcPossibles[@]}")

  #possibles=("${releasesPossibles[@]}" "${rcPossibles[@]}")

  if [ "${#possibles[@]}" -eq 0 ]; then
    _error "error: unable to determine available releases of $version"
  fi

  for i in "${possibles[@]}"; do
    eval "possi=( ${i} )"
    fullVersion="${possi[0]}"
    url="${possi[1]}"
    ascUrl="${possi[2]}"
    sha256="${possi[3]}"
    md5="${possi[4]}"
    date="${possi[5]}"

    _info "
  fullVersion: $fullVersion
  url: $url
  ascUrl: $ascUrl
  sha256: $sha256
  md5: $md5
  date: $date
  "

    # 文件已存在跳过
    [ ! -d "docs" ] && mkdir -p docs

    if [ -f "docs/${fullVersion}.md" ]; then
      _succ "success: docs/${fullVersion}.md is exists; skip"
      continue
    fi

    if ! wget -q --spider "$url"; then
      _red "error: '$url' appears to be missing; skip"
      continue
    fi

    # 检查$ascUrl打不开就清空（老版本没有这个asc文件），本身就没有的话尝试获取
    if [ ! -z "$ascUrl" ]; then
      if ! wget -q --spider "$ascUrl"; then
        _warn "warn: '$ascUrl' appears to be missing"
        ascUrl=""
      fi
    elif wget -q --spider "$url.asc"; then
      ascUrl="$url.asc"
    fi

    if [ "$fullVersion" = '8.0.2' ]; then
      # https://bugs.php.net/bug.php?id=80711#1612456954 😬
      url+='?a=1'
      ascUrl+='?a=1'
    fi

    [ ! -d "src/${fullVersion}" ] && mkdir -p src/${fullVersion}

    # 下载文件
    downFile="php-${fullVersion}.tar.gz"
    [ ! -f "$downFile" ] && _info "download ${downFile}" && wget -c "$url" -qO "$downFile"

    #    tar -xzvf "$fileName" -C src/${fullVersion} php-${fullVersion}/configure --strip-components=1

    _info "unpack ${downFile}"
    tar -xzf "$downFile" -C src/${fullVersion} --strip-components=1 --checkpoint=1000 --checkpoint-action=dot --totals

    _info "write to docs/${fullVersion}.md "
    cat >"docs/${fullVersion}.md" <<EOF
# ${fullVersion} configure help info

\`\`\`bash
$(src/${fullVersion}/configure --help)
\`\`\`

- 版本：${fullVersion}
- 时间：${date}
- [下载地址](${url})
- sha256：${sha256}
- md5：${md5}
EOF

    addVersions+=("${fullVersion}")

    _succ "success" && _info "cleanup source src/${fullVersion} $downFile"

    rm -rf src/${fullVersion}
    rm -rf $downFile

  done

done

# commit
if [ ! "${#addVersions[@]}" -eq 0 ]; then
  git config --local user.email "action@github.com"
  git config --local user.name "GHA"
  git add docs/
  git commit -m "🤖 Add ${addVersions[*]}" -a
fi
