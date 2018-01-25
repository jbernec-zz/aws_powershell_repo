#Set and Initialize AWS Credential and Profile for login and authentication
Set-AWSCredential -AccessKey AKIAIFYCSZ8M2IYRWD5B -SecretKey 1daQ62lpSzb8R4OorYg6pAjU1tk0WBUESLiNEdky -StoreAs AWSDemoProfile
Initialize-AWSDefaultConfiguration -ProfileName AWSDemoProfile -Region us-west-1

#Create Keypair for decrypting login creds
$awskey = New-EC2KeyPair -KeyName mykeypair
$awskey.KeyMaterial | Out-File -FilePath C:\AWSCred\mykeypair.pem

#Create non default virtual private cloud/virtual network, enable dns hostnames and tag the vpc resource
$Ec2Vpc = New-EC2Vpc -CidrBlock "10.0.0.0/16" -InstanceTenancy default
Edit-EC2VpcAttribute -VpcId $Ec2Vpc.VpcId -EnableDnsHostnames $true
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = "Name"
$Tag.Value = "MyVPC"
New-EC2Tag -Resource $Ec2Vpc.VpcId -Tag $Tag

#Create non default subnet and tag the subnet resource
$Ec2subnet = New-EC2Subnet -VpcId $Ec2Vpc.VpcId -CidrBlock "10.0.0.0/24"
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = "Name"
$Tag.Value = "MySubnet"
New-EC2Tag -Resource $Ec2subnet.SubnetId -Tag $Tag
#Edit-EC2SubnetAttribute -SubnetId $ec2subnet.SubnetId -MapPublicIpOnLaunch $true

#Create Internet Gateway and attach it to the VPC
$Ec2InternetGateway = New-EC2InternetGateway
Add-EC2InternetGateway -InternetGatewayId $Ec2InternetGateway.InternetGatewayId -VpcId $ec2Vpc.VpcId
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = "Name"
$Tag.Value = "MyInternetGateway"
New-EC2Tag -Resource $Ec2InternetGateway.InternetGatewayId -Tag $Tag

#Create custom route table with route to the internet and associate it with the subnet
$Ec2RouteTable = New-EC2RouteTable -VpcId $ec2Vpc.VpcId
New-EC2Route -RouteTableId $Ec2RouteTable.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -GatewayId $Ec2InternetGateway.InternetGatewayId
Register-EC2RouteTable -RouteTableId $Ec2RouteTable.RouteTableId -SubnetId $ec2subnet.SubnetId

#Create Security group and firewall rule for RDP
$SecurityGroup = New-EC2SecurityGroup -Description "Non Default RDP Security group for AWS VM" -GroupName "RDPSecurityGroup" -VpcId $ec2Vpc.VpcId
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = "Name"
$Tag.Value = "RDPSecurityGroup"
New-EC2Tag -Resource $securityGroup -Tag $Tag
$iprule = New-Object Amazon.EC2.Model.IpPermission
$iprule.ToPort = 3389
$iprule.FromPort = 3389
$iprule.IpProtocol = "tcp"
$iprule.IpRanges.Add('0.0.0.0/0')
Grant-EC2SecurityGroupIngress -GroupId $securityGroup -IpPermission $iprule -Force


#Retrieve Amazon Machine Image Id property for Windows Server 2016
$imageid = (Get-EC2ImageByName -Name WINDOWS_2016_BASE).ImageId

#Allocate an Elastic IP Address for use with an instance VM
$Ec2Address = New-EC2Address -Domain vpc
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = "Name"
$Tag.Value = "MyElasticIP"
New-EC2Tag -Resource $Ec2Address.AllocationId -Tag $Tag

#Launch EC2Instance Virtual Machine
$ec2instance = New-EC2Instance -ImageId $imageid -MinCount 1 -MaxCount 1 -InstanceType t2.micro -KeyName mykeypair -SecurityGroupId $securityGroup -Monitoring_Enabled $true -SubnetId $ec2subnet.SubnetId
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = "Name"
$Tag.Value = "MyVM"
$InstanceId = $ec2instance.Instances | Select-Object -ExpandProperty InstanceId
New-EC2Tag -Resource $InstanceId -Tag $Tag

#Assign Elastic IP Address to the EC2 Instance VM
$DesiredState = "Running"
while ($true) {
    $State = (Get-EC2Instance -InstanceId $InstanceId).Instances.State.Name.Value
    if ($State -eq $DesiredState) {
        break;
    }
    "$(Get-Date) Current State = $State, Waiting for Desired State=$DesiredState"
    Start-Sleep -Seconds 5
}
Register-EC2Address -AllocationId $Ec2Address.AllocationId -InstanceId $InstanceId

#Display VM instance properties
(Get-EC2Instance -InstanceId $InstanceId).Instances | Format-List

#Clean up and Terminate the EC2 Instance
#Get-EC2Instance | Remove-EC2Instance -Force