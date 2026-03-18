# ============================================
# 01-network.ps1
# Creates: Resource Group, VNet, Subnets, NSGs
# ============================================

# ---------- VARIABLES ----------
$resourceGroup    = "rg-multitier-ha"
$location         = "eastus"
$vnetName         = "vnet-multitier"
$vnetPrefix       = "10.0.0.0/16"

# Subnet prefixes
$subnetFrontend   = "10.0.1.0/24"
$subnetBackend    = "10.0.2.0/24"
$subnetDatabase   = "10.0.3.0/24"
$subnetGateway    = "10.0.4.0/24"

# NSG Names
$nsgFrontend      = "nsg-frontend"
$nsgBackend       = "nsg-backend"
$nsgDatabase      = "nsg-database"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Starting Network Deployment..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ---------- STEP 1: Create Resource Group ----------
Write-Host "`n[1/7] Creating Resource Group..." -ForegroundColor Yellow
New-AzResourceGroup -Name $resourceGroup -Location $location -Force
Write-Host "✅ Resource Group created." -ForegroundColor Green

# ---------- STEP 2: Create NSG for Frontend ----------
Write-Host "`n[2/7] Creating Frontend NSG..." -ForegroundColor Yellow
$nsgFrontendRules = @(
    New-AzNetworkSecurityRuleConfig -Name "Allow-HTTP" `
        -Protocol Tcp -Direction Inbound -Priority 100 `
        -SourceAddressPrefix "*" -SourcePortRange "*" `
        -DestinationAddressPrefix "*" -DestinationPortRange 80 `
        -Access Allow,

    New-AzNetworkSecurityRuleConfig -Name "Allow-HTTPS" `
        -Protocol Tcp -Direction Inbound -Priority 110 `
        -SourceAddressPrefix "*" -SourcePortRange "*" `
        -DestinationAddressPrefix "*" -DestinationPortRange 443 `
        -Access Allow
)
$nsgFe = New-AzNetworkSecurityGroup -Name $nsgFrontend `
    -ResourceGroupName $resourceGroup -Location $location `
    -SecurityRules $nsgFrontendRules
Write-Host "✅ Frontend NSG created." -ForegroundColor Green

# ---------- STEP 3: Create NSG for Backend ----------
Write-Host "`n[3/7] Creating Backend NSG..." -ForegroundColor Yellow
$nsgBackendRules = @(
    New-AzNetworkSecurityRuleConfig -Name "Allow-Frontend-To-Backend" `
        -Protocol Tcp -Direction Inbound -Priority 100 `
        -SourceAddressPrefix $subnetFrontend -SourcePortRange "*" `
        -DestinationAddressPrefix "*" -DestinationPortRange 8080 `
        -Access Allow
)
$nsgBe = New-AzNetworkSecurityGroup -Name $nsgBackend `
    -ResourceGroupName $resourceGroup -Location $location `
    -SecurityRules $nsgBackendRules
Write-Host "✅ Backend NSG created." -ForegroundColor Green

# ---------- STEP 4: Create NSG for Database ----------
Write-Host "`n[4/7] Creating Database NSG..." -ForegroundColor Yellow
$nsgDatabaseRules = @(
    New-AzNetworkSecurityRuleConfig -Name "Allow-Backend-To-DB" `
        -Protocol Tcp -Direction Inbound -Priority 100 `
        -SourceAddressPrefix $subnetBackend -SourcePortRange "*" `
        -DestinationAddressPrefix "*" -DestinationPortRange 1433 `
        -Access Allow
)
$nsgDb = New-AzNetworkSecurityGroup -Name $nsgDatabase `
    -ResourceGroupName $resourceGroup -Location $location `
    -SecurityRules $nsgDatabaseRules
Write-Host "✅ Database NSG created." -ForegroundColor Green

# ---------- STEP 5: Create Subnets ----------
Write-Host "`n[5/7] Creating Subnets..." -ForegroundColor Yellow
$subnetConfigFrontend = New-AzVirtualNetworkSubnetConfig `
    -Name "subnet-frontend" -AddressPrefix $subnetFrontend `
    -NetworkSecurityGroup $nsgFe

$subnetConfigBackend = New-AzVirtualNetworkSubnetConfig `
    -Name "subnet-backend" -AddressPrefix $subnetBackend `
    -NetworkSecurityGroup $nsgBe

$subnetConfigDatabase = New-AzVirtualNetworkSubnetConfig `
    -Name "subnet-database" -AddressPrefix $subnetDatabase `
    -NetworkSecurityGroup $nsgDb

$subnetConfigGateway = New-AzVirtualNetworkSubnetConfig `
    -Name "GatewaySubnet" -AddressPrefix $subnetGateway
Write-Host "✅ Subnets configured." -ForegroundColor Green

# ---------- STEP 6: Create Virtual Network ----------
Write-Host "`n[6/7] Creating Virtual Network..." -ForegroundColor Yellow
New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AddressPrefix $vnetPrefix `
    -Subnet $subnetConfigFrontend, $subnetConfigBackend, `
             $subnetConfigDatabase, $subnetConfigGateway
Write-Host "✅ Virtual Network created." -ForegroundColor Green

# ---------- STEP 7: Verify ----------
Write-Host "`n[7/7] Verifying deployment..." -ForegroundColor Yellow
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroup
Write-Host "`n✅ VNet Name    : $($vnet.Name)" -ForegroundColor Green
Write-Host "✅ Location     : $($vnet.Location)" -ForegroundColor Green
Write-Host "✅ Subnets      : $($vnet.Subnets.Count)" -ForegroundColor Green
$vnet.Subnets | ForEach-Object {
    Write-Host "   → $($_.Name) : $($_.AddressPrefix)" -ForegroundColor White
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " ✅ Network Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan