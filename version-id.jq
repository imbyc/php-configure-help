# modify From https://github.com/docker-library/php/blob/master/version-id.jq
def version_id:
	# https://www.php.net/phpversion
	# $version_id = $major_version * 10000 + $minor_version * 100 + $release_version;
	sub("[a-zA-Z].*$"; "")
	| split(".")
	| (
		(.[0] // 0 | tonumber) * 10000
		+ (.[1] // 0 | tonumber) * 100
		+ (.[2] // 0 | tonumber)
	)
;
# 主版本号
def major_version($fullVersion):
    $fullVersion | sub("[a-zA-Z].*$"; "")
    | split(".")
    | (.[0] // 0 | tostring)
;
# 不同下载地址
def download_url($fullVersion;$museum):
    if $museum then
        "https://museum.php.net/php" + major_version($fullVersion) + "/"
    else
        "https://www.php.net/distributions/"
    end
;
