# shellcheck shell=bash disable=SC2154
export MSBUILDALWAYSOVERWRITEREADONLYFILES=1

declare -Ag _nugetInputs

addNugetInputs() {
    if [[ -d $1/share/nuget ]]; then
        _nugetInputs[$1]=1
        if [[ -d $1/share/nuget/packages ]]; then
            addToSearchPathWithCustomDelimiter ";" NUGET_FALLBACK_PACKAGES "$1/share/nuget/packages"
        fi
    fi
}

addEnvHooks "$targetOffset" addNugetInputs

_linkPackages() {
    local -r src="$1"
    local -r dest="$2"
    local dir

    (
        shopt -s nullglob
        for x in "$src"/*/*; do
            dir=$dest/$(basename "$(dirname "$x")")
            mkdir -p "$dir"
            ln -s "$x" "$dir"/
        done
    )
}

createNugetDirs() {
    nugetTemp=$PWD/.nuget-temp
    # trailing slash required here:
    # Microsoft.Managed.Core.targets(236,5): error : SourceRoot paths are required to end with a slash or backslash: '/build/.nuget-temp/packages'
    export NUGET_PACKAGES=$nugetTemp/packages/
    nugetSource=$nugetTemp/source
    mkdir -p "$NUGET_PACKAGES" "$nugetSource"

    dotnet new nugetconfig
    if [[ -z ${keepNugetConfig-} ]]; then
        dotnet nuget disable source nuget
    fi

    dotnet nuget add source "$nugetSource" -n _nix
}

configureNuget() {
    for x in "${!_nugetInputs[@]}"; do
        if [[ -d $x/share/nuget/source ]]; then
            _linkPackages "$x/share/nuget/source" "$nugetSource"
        fi
    done

    if [[ -n "${linkNugetPackages-}"
        || -f .config/dotnet-tools.json
        || -f dotnet-tools.json
        || -f paket.dependencies ]]; then
        for x in "${!_nugetInputs[@]}"; do
            if [[ -d $x/share/nuget/packages ]]; then
                @lndir@/bin/lndir -silent "$x/share/nuget/packages" "$NUGET_PACKAGES"
            fi
        done
    fi

    if [[ -f paket.dependencies ]]; then
       sed -i "s:source .*:source $nugetSource:" paket.dependencies
       sed -i "s:remote\:.*:remote\: $nugetSource:" paket.lock

       for x in "${!_nugetInputs[@]}"; do
           if [[ -d $x/share/nuget/source ]]; then
               @lndir@/bin/lndir -silent "$x/share/nuget/source" "$NUGET_PACKAGES"
           fi
       done

    fi

    if [[ -n "${makeEmptyNupkgInPackages-}" ]]; then
        (
            shopt -s nullglob
            for package in "$NUGET_PACKAGES"/*/*; do
                version=$(basename "$package")
                id=$(basename "$(dirname "$package")")
                touch "$package/$id.$version.nupkg"
            done
        )
    fi
}

if [[ -z ${dontConfigureNuget-} ]]; then
    prePhases+=(createNugetDirs)
    preConfigurePhases+=(configureNuget)
fi
