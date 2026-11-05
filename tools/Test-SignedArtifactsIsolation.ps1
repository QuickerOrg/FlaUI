$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projects=@(
    @{name='FlaUI.Core';tfm='net10.0-windows10.0.19041.0'},
    @{name='FlaUI.UIA2';tfm='net8.0-windows'},
    @{name='FlaUI.UIA3';tfm='net10.0-windows10.0.19041.0'}
)
$count=0
foreach($project in $projects){
    $path=Join-Path $root "src/$($project.name)/$($project.name).csproj"
    foreach($platform in @('x64','ARM64')){
        foreach($withRid in @($false,$true)){
            $rid=if($withRid){'win-'+$platform.ToLowerInvariant()}else{''}
            $values=@{}
            foreach($signed in @('false','true')){
                $json=& dotnet msbuild $path -nologo -p:Configuration=Release "-p:Platform=$platform" "-p:TargetFramework=$($project.tfm)" "-p:RuntimeIdentifier=$rid" "-p:EnableSigning=$signed" -p:UseArtifactsOutput=true "-p:ArtifactsPath=$root/artifacts/property-tests" '-getProperty:PlatformTarget,RuntimeIdentifier,OutputPath,BaseIntermediateOutputPath,MSBuildProjectExtensionsPath,IntermediateOutputPath,TargetPath,TargetRefPath'
                if($LASTEXITCODE -ne 0){throw 'Project property evaluation failed'}
                $value=($json | ConvertFrom-Json).Properties
                if($value.PlatformTarget -ne 'AnyCPU' -or $value.RuntimeIdentifier -ne $rid){throw 'Compiler target or host RID changed'}
                $values[$signed]=$value
                $count++
            }
            foreach($property in @('OutputPath','BaseIntermediateOutputPath','MSBuildProjectExtensionsPath','IntermediateOutputPath','TargetPath','TargetRefPath')){
                if($values.true.$property -eq $values.false.$property){throw "Signed/unsigned share $property for $($project.name) $platform RID='$rid'"}
            }
        }
    }
}
Write-Host "PASS signed/unsigned artifacts isolation: $count evaluations across Core/UIA2/UIA3, x64/ARM64, with/without RID."
