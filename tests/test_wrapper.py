import pytest
from ape.utils import ZERO_ADDRESS

@pytest.fixture
def receiver(accounts, request):
    return accounts[request.param]

@pytest.fixture
def owner(accounts, request):
    return accounts[request.param]

@pytest.mark.parametrize('token', ['weth', 'wbtc', 'usdc', 'arb', 'gmx', 'rdnt'])
def test_aux(accounts, Contract, crayon_desk, token, desks_data):
    desk = crayon_desk(token)
    assert desk.asset() == desks_data[token]['token']
    a = accounts[1]
    b = accounts[2]

    decimals = desk.decimals()
    asset_decimals = desks_data[token]['decimals']
    asset_amount = 100 * 10 ** asset_decimals
    share_amount = 100 * 10 ** decimals

    assert desk.totalAssets() == 0
    assert desk.convertToAssets(share_amount) == 0  # no assets
    assert desk.convertToShares(asset_amount) == share_amount # 1:1 price
    assert desk.previewDeposit(asset_amount) == share_amount # 1:1 price
    assert desk.previewMint(share_amount) == asset_amount # 1:1 price
    assert desk.previewWithdraw(asset_amount) == 0  # but no assets
    assert desk.previewRedeem(share_amount) == 0  # but no assets

    asset = Contract(desk.asset())

    asset.approve(desk, asset_amount, sender=a)
    tx = desk.deposit(asset_amount, sender=a)

    for e in [
        desk.Transfer(ZERO_ADDRESS, a, share_amount),
        desk.Deposit(a, a, asset_amount, share_amount)
    ]:
        assert e in tx.events

    assert desk.maxDeposit(a) == 2**256 - 1
    assert desk.maxMint(a) == 2**256 - 1
    assert desk.maxWithdraw(a) == asset_amount
    assert desk.maxRedeem(a) == desk.balanceOf(a)

    assert desk.totalAssets() == asset_amount
    assert desk.convertToAssets(share_amount) == asset_amount  # 1:1 price
    assert desk.convertToShares(asset_amount) == share_amount  # 1:1 price
    assert desk.previewDeposit(asset_amount) == share_amount  # 1:1 price
    assert desk.previewMint(share_amount) == asset_amount  # 1:1 price
    assert desk.previewWithdraw(asset_amount) == share_amount  # 1:1 price
    assert desk.previewRedeem(share_amount) == asset_amount  # 1:1 price

    b_asset_amount = asset_amount // 2
    b_share_amount = share_amount // 2
    asset.approve(desk, b_asset_amount, sender=b)
    tx = desk.deposit(b_asset_amount, sender=b)

    assert desk.balanceOf(a) == share_amount
    assert desk.balanceOf(b) == b_share_amount
    
    bal = asset.balanceOf(a)
    sbal = desk.balanceOf(a)
    sc = desk.convertToShares(asset_amount // 3)
    assert desk.totalSupply() == share_amount + b_share_amount
    assert desk.totalAssets() == asset_amount + b_asset_amount
    assert sbal // 3 == sc 
    desk.withdraw(asset_amount // 3, sender=a)
    assert asset.balanceOf(a) == bal + asset_amount // 3
    assert desk.balanceOf(a) == sbal - sc

    new_assets = desk.previewMint(share_amount // 4)
    bbal = asset.balanceOf(b)
    asset.approve(desk, new_assets, sender=b)
    desk.mint(share_amount // 4, sender=b)
    assert asset.balanceOf(b) == bbal - new_assets

    desk.redeem(share_amount // 4, sender=b)
    assert asset.balanceOf(b) == bbal

@pytest.mark.parametrize('owner', [1, 2, 3], indirect=True)
@pytest.mark.parametrize('receiver', [1, 2, 3], indirect=True)
@pytest.mark.parametrize('token', ['usdc', 'weth', 'wbtc', 'arb', 'gmx', 'rdnt'])
def test_ops(accounts, Contract, desks_data, crayon_desk, token, receiver, owner):
    a = accounts[1]
    asset_decimals = desks_data[token]['decimals']
    asset_amount = 100 * 10 ** asset_decimals

    desk = crayon_desk(token)
    asset = Contract(desk.asset())

    asset.approve(desk, asset_amount, sender=a)
    desk.deposit(asset_amount, owner, sender=a)

    bal = asset.balanceOf(receiver)
    share_bal = desk.balanceOf(owner)
    shares = desk.previewWithdraw(asset_amount // 2)
    desk.approve(a, shares, sender = owner)
    desk.withdraw(asset_amount // 2, receiver, owner, sender=a)
    assert desk.balanceOf(owner) == share_bal - shares
    assert asset.balanceOf(receiver) == bal + asset_amount // 2

    decimals = desk.decimals()
    share_amount = 111 * 10 ** decimals
    assets = desk.previewMint(share_amount)
    asset.approve(desk, assets, sender=a)
    desk.mint(share_amount, owner, sender=a)
    desk.approve(a, share_amount // 2, sender=owner)
    asset_bal = asset.balanceOf(receiver)
    assets = desk.previewRedeem(share_amount // 2)
    share_bal = desk.balanceOf(owner)
    desk.redeem(share_amount // 2, receiver, owner, sender=a)
    assert desk.balanceOf(owner) == share_bal - share_amount // 2
    assert asset.balanceOf(receiver) == asset_bal + assets