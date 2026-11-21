<#-- The license check supplies both maps after applying its inherited policy. -->
{
    "generatedAt": "${.now?iso_utc}",
    "packages": [
    <#list dependencyMap as entry>
        <#assign artifact = entry.getKey()>
        {
            "group": "${artifact.groupId?json_string}",
            "artifact": "${artifact.artifactId?json_string}",
            "version": "${artifact.version?json_string}",
            "declared": [
            <#list artifact.licenses as license>
                "${(license.name!license.url!"")?json_string}"<#sep>,
            </#list>
            ],
            "normalized": [
            <#list entry.getValue() as license>
                "${license?json_string}"<#sep>,
            </#list>
            ]
        }<#sep>,
    </#list>
    ]
}
