if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore()

$asaCredential = Get-Credential -UserName someuser -Message "Please provide a password"
$username = "someuser"

$password = Read-Host "please enter password"
$userpass  = $username + “:” + $password


$bytes= [System.Text.Encoding]::UTF8.GetBytes($userpass)
$encodedlogin=[Convert]::ToBase64String($bytes)
$authheader = "Basic " + $encodedlogin

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$authheader)
$headers.Add("Accept","application/json")
$headers.Add("Content-Type","application/json")

$headers.Add("X-auth-access-token","e4cea852-104f-48ce-9a59-75d00524344b")
$headers.Add("X-auth-refresh-token","3388b5c2-c83e-4af9-91d5-33efc5ae3246")

$refreshheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$refreshheaders.Add("Authorization",$authheader)
$refreshheaders.'X-auth-access-token'= "3ee87dfc-43fa-4faf-ad1b-a1a52ba69a0c"
$refreshheaders."X-auth-refresh-token"= "d6698282-6bc5-4520-ac09-4bf6c926888c"

$ipaddress = Read-Host "Please enter ip address of ASA to connect to"

$headers.'X-auth-access-token'= $refreshheaders.'X-auth-access-token'

$ASABaseURI = "https://$ipaddress/api"

$response = Invoke-WebRequest -Uri ($ASABaseURI + "/tokenservices") -Headers $headers -Method Post 

#use to refesh the token after the 30 min timeout
$refeshauthtoken = Invoke-WebRequest -Uri $ASABaseURI -Headers $refreshheaders -Method Post 
$refreshheaders.'X-auth-access-token'= $refeshauthtoken.Headers.'X-auth-access-token'
$refreshheaders."X-auth-refresh-token"= $refeshauthtoken.Headers.'X-auth-refresh-token'


#reassign the refreshed values to main headers for API communication
$headers.'X-auth-access-token'= $refreshheaders.'X-auth-access-token'


$ASAObjectsURI = $ASABaseURI + "/objects"
$ASANEtworkObjectsURI = $ASAObjectsURI + "/networkobjects" 
$ASAInterfacesURI = $ASABaseURI + "/interfaces/physical"

 $asaNetworkObjects = (Invoke-WebRequest -Uri $ASANEtworkObjectsURI -Headers $headers -Method Get).content
$convertedAsaNetworkObjects = ($asaNetworkObjects | ConvertFrom-Json).items

$networkObjects = @()


foreach($object in $convertedAsaNetworkObjects){
$networkObjects += $item
}

$interfaceslist = @()

$physicalinterfacesrequest = ( (Invoke-WebRequest -Uri $ASAInterfacesURI -Headers $headers -Method Get).Content | ConvertFrom-Json)


foreach($interface in $physicalinterfacesrequest.items){
$interfaceslist += $interface
}


$masterACLEntriesList = @()

#populate an array with list of acls' by each interface

foreach($interfaceID in $interfaceslist){
$uri = $ASABaseURI + "/access/in/" + $interfaceID.name + "/rules"

$request = ((Invoke-WebRequest -Uri $uri -Headers $headers -Method Get).Content | ConvertFrom-Json)

$masterACLEntriesList += $request
}

#build lists of network and service objects
$networkObjectGroups = @()

$networkObjects = @()

$networkServiceObjectGroups = @()

$networkServiceObjects = @()

$staticNetworkRoutes = @()

$networkObjectsrequest = ((Invoke-WebRequest -uri ($ASABaseURI + "/objects/networkobjects/") -Headers $headers -method get).content | ConvertFrom-Json)

foreach($networkObject in $networkObjectsrequest.items){

$networkObjects += $networkObject

}

#get network object groups from ASA and populate in networkobjectgroups array
$networkObjectGroupsrequest = ((Invoke-WebRequest -uri ($ASABaseURI + "/objects/networkobjectgroups/") -Headers $headers -method get).content | ConvertFrom-Json)
$networkObjectGroups += $networkObjectGroupsrequest.items

#getnetworkservice objects from ASA and populate in networkserviceobjects array
$networkServiceObjectsRequest = ((Invoke-WebRequest -uri ($ASABaseURI + "/objects/networkservices/") -Headers $headers -method get).content | ConvertFrom-Json)
$networkServiceObjects += $networkServiceObjectsRequest.items

#get network service object groups from ASA and populate in network service object groups array
$networkServiceGroupsrequest = ((Invoke-WebRequest -uri ($ASABaseURI + "/objects/networkservicegroups/") -Headers $headers -method get).content | ConvertFrom-Json)
$networkServiceObjectGroups += $networkServiceGroupsrequest.items

#get network routes

$networkRoutesRequest = ((Invoke-WebRequest -uri ($ASABaseURI + "/routing/static/") -Headers $headers -method get).content | ConvertFrom-Json)
$staticNetworkRoutes += $networkRoutesRequest.items

######################################################################WRITE DATA TO NEW ASA#####################################################################

$newPassword = Read-Host -Prompt "Please enter new ASA Password"

$newUserPass = $username + “:” + $newpassword

$bytes= [System.Text.Encoding]::UTF8.GetBytes($newUserpass)
$encodedlogin=[Convert]::ToBase64String($bytes)
$authheader = "Basic " + $encodedlogin

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$authheader)
$headers.Add("Accept","application/json")
$headers.Add("Content-Type","application/json")

$headers.Add("X-auth-access-token","e4cea852-104f-48ce-9a59-75d00524344b")
$headers.Add("X-auth-refresh-token","3388b5c2-c83e-4af9-91d5-33efc5ae3246")

$refreshheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$refreshheaders.Add("Authorization",$authheader)
$refreshheaders.'X-auth-access-token'= "3ee87dfc-43fa-4faf-ad1b-a1a52ba69a0c"
$refreshheaders."X-auth-refresh-token"= "d6698282-6bc5-4520-ac09-4bf6c926888c"


$headers.'X-auth-access-token'= $refreshheaders.'X-auth-access-token'

$ASABaseURI = "https://199.239.140.133/api"

$ASANetworkObjectsURI = $ASABaseURI + "/objects/networkobjects"

$response = Invoke-WebRequest -Uri ($ASABaseURI + "/tokenservices") -Headers $headers -Method Post 

#use to refesh the token after the 30 min timeout
$refeshauthtoken = Invoke-WebRequest -Uri $ASABaseURI -Headers $refreshheaders -Method Post 
$refreshheaders.'X-auth-access-token'= $refeshauthtoken.Headers.'X-auth-access-token'
$refreshheaders."X-auth-refresh-token"= $refeshauthtoken.Headers.'X-auth-refresh-token'


#reassign the refreshed values to main headers for API communication
$headers.'X-auth-access-token'= $refreshheaders.'X-auth-access-token'

$networkObjectResponses = @()
foreach($networkObject in $networkObjects){

$networkObjectResponses += Invoke-WebRequest -Uri $ASANetworkObjectsURI -Headers $headers -Method Post -Body ($networkobject | ConvertTo-Json -Depth 5 )
}

$serviceObjectResponses = @()

foreach($svr in $networkServiceObjects){

$serviceObjectResponses += Invoke-WebRequest -Uri ($ASABaseURI + "/objects/networkservices/") -Headers $headers -Method Post -Body ($svr | ConvertTo-Json -Depth 5 )
}


$networkRoutesResponses = @()

foreach($snr in $staticNetworkRoutes){

$snr.interface.objectId = ""
$networkRoutesResponses += Invoke-WebRequest -Uri ($ASABaseURI + "/routing/static/") -Headers $headers -Method Post -Body ($snr | ConvertTo-Json -Depth 5 )

}