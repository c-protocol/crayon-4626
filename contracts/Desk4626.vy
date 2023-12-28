# @version 0.3.10
# (c) Crayon Protocol Authors, 2023
#
# Relied on following implementations of ERC-4626 specification:
#
# https://github.com/fubuloubu/ERC4626/blob/main/contracts/VyperVault.vy
# https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol
#

from vyper.interfaces import ERC20

import ERC4626 as ERC4626

implements: ERC20
implements: ERC4626

interface CrayonDesk:
    def deposit(
        _amount: uint256,
        _provider: address = empty(address)
    ): nonpayable

    def withdraw(
        _amount: uint256,
        _provider: address = empty(address)
    ): nonpayable

    def base_coin() -> address: view

    def base_coin_decimals() -> uint8: view
    
    def balanceOf(
        _user: address
    ) -> uint256: view

    def total_liquidity() -> uint256: view

##### ERC20 #####

totalSupply: public(uint256)
balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])

# shortest precision on any of our desks
DECIMALS: constant(uint8) = 6

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    amount: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    allowance: uint256

##### ERC4626 #####

asset: public(ERC20)
desk: public(CrayonDesk)
symbol: public(String[6])
name: public(String[11])

asset_decimals: uint8

event Deposit:
    depositor: indexed(address)
    receiver: indexed(address)
    assets: uint256
    shares: uint256

event Withdraw:
    withdrawer: indexed(address)
    receiver: indexed(address)
    owner: indexed(address)
    assets: uint256
    shares: uint256


@external
def __init__(_desk: address, _symbol: String[6], _name: String[11]):
    self.desk = CrayonDesk(_desk)
    self.symbol = _symbol
    self.name = _name
    self.asset = ERC20(CrayonDesk(_desk).base_coin())
    self.asset_decimals =  CrayonDesk(_desk).base_coin_decimals()

@view
@external
def decimals() -> uint8:
    return DECIMALS


@external
def transfer(_receiver: address, _amount: uint256) -> bool:
    self.balanceOf[msg.sender] -= _amount
    self.balanceOf[_receiver] += _amount
    log Transfer(msg.sender, _receiver, _amount)
    return True


@external
def approve(_spender: address, _amount: uint256) -> bool:
    self.allowance[msg.sender][_spender] = _amount
    log Approval(msg.sender, _spender, _amount)
    return True


@external
def transferFrom(_sender: address, _receiver: address, _amount: uint256) -> bool:
    self.allowance[_sender][msg.sender] -= _amount
    self.balanceOf[_sender] -= _amount
    self.balanceOf[_receiver] += _amount
    log Transfer(_sender, _receiver, _amount)
    return True


@view
@external
def totalAssets() -> uint256:
    """
    @notice Returns the total deposited amount of asset
    @dev The standard requires including any gains from yield therefore the balance should be checked on the desk not the asset contract so unrealized gains are included
    @return The total deposited amount of asset
    """

    return self.desk.balanceOf(self)


@view
@internal
def _convertToAssets(_shareAmount: uint256) -> uint256:
    """
    @dev Calculate the amount of asset tokens redeemable against _shareAmount
    @param _shareAmount The amount of shares
    @return The amount of asset that can be obtained by redeeming the shares
    """

    totalSupply: uint256 = self.totalSupply
    if totalSupply == 0:
        return 0

    return _shareAmount * self.desk.balanceOf(self) / totalSupply


@view
@external
def convertToAssets(_shareAmount: uint256) -> uint256:
    """
    @notice Calculate the amount of asset that can be obtained by redeeming the shares
    @param _shareAmount The amount of shares
    @return The amount of asset that can be obtained by redeeming the shares
    """

    return self._convertToAssets(_shareAmount)


@view
@internal
def _convertToShares(_assetAmount: uint256) -> uint256:
    """
    @dev Calculate the number of shares that can be obtained when _assetAmount is deposited
    @param _assetAmount The amount of underlying asset to be deposited
    @return The number of shares
    """

    totalSupply: uint256 = self.totalSupply
    # get total balance from the desk to account for unrealized gains
    totalAssets: uint256 = self.desk.balanceOf(self)
    if totalAssets == 0 or totalSupply == 0:
        return _assetAmount * 10 ** convert(DECIMALS, uint256) / 10 ** convert(self.asset_decimals, uint256) # 1:1 price

    return _assetAmount * totalSupply / totalAssets


@view
@external
def convertToShares(_assetAmount: uint256) -> uint256:
    """
    @notice Calculate the number of shares that can be obtained when _assetAmount is deposited
    @param _assetAmount The amount of underlying asset to be deposited
    @return The number of shares
    """

    return self._convertToShares(_assetAmount)


@view
@external
def maxDeposit(_owner: address) -> uint256:
    """
    @notice We apply no restrictions on the amount that can be deposited
    @param _owner Ignored
    @return The max uint value
    """

    return max_value(uint256)


@view
@external
def previewDeposit(_assets: uint256) -> uint256:
    """
    @notice Calculate the number of shares that will be minted for a deposit of _assets
    @param _assets The number of tokens to be deposited
    @return The number of shares
    """

    return self._convertToShares(_assets)

@internal
def _deposit_desk(_assets : uint256):
    """
    @dev Deposit amount of asset tokens in the underlying desk
    @param _assets The amount of self.asset to be deposited
    """

    desk: address = self.desk.address
    asset: ERC20 = self.asset
    # approve the desk for the transfer
    allowance : uint256 = asset.allowance(self, desk)
    asset.approve(desk, _assets + allowance)
    # deposit
    self.desk.deposit(_assets)

@external
@nonreentrant('lock')
def deposit(_assets: uint256, _receiver: address=msg.sender) -> uint256:
    """
    @notice Deposit asset
    @param _assets The amount to deposit
    @param _receiver The address of the owner to be credited with the deposit
    @return The number of shares created and credited to _receiver
    """

    shares: uint256 = self._convertToShares(_assets)
    self.asset.transferFrom(msg.sender, self, _assets)
    # deposit in Crayon desk
    self._deposit_desk(_assets)

    self.totalSupply += shares
    self.balanceOf[_receiver] += shares
    log Transfer(empty(address), _receiver, shares)
    log Deposit(msg.sender, _receiver, _assets, shares)
    return shares


@view
@external
def maxMint(_owner: address) -> uint256:
    """
    @notice We apply no restrictions of the number of requested shares
    @param _owner Ignored
    @return The max uint value
    """

    return max_value(uint256)


@view
@external
def previewMint(_shares: uint256) -> uint256:
    """
    @notice Calculate the number of asset tokens that would be required for shares to be minted
    @param _shares The desired number of shares
    @return The number of asset tokens
    """

    assets: uint256 = self._convertToAssets(_shares)

    # NOTE: Vyper does lazy eval on if, so this avoids SLOADs most of the time
    if assets == 0 and self.desk.balanceOf(self) == 0:
        return _shares * 10 ** convert(self.asset_decimals, uint256) / 10 ** convert(DECIMALS, uint256) # NOTE: Assume 1:1 price if nothing deposited yet

    return assets


@external
@nonreentrant('lock')
def mint(_shares: uint256, _receiver: address=msg.sender) -> uint256:
    """
    @notice Mint specific number of shares and transfer from msg.sender required assets
    @param _shares The desired number of shares
    @param _receiver The recipient of the shares
    @return The number of asset tokens that were to self from msg.sender
    """

    assets: uint256 = self._convertToAssets(_shares)

    if assets == 0 and self.desk.balanceOf(self) == 0:
        assets = _shares * 10 ** convert(self.asset_decimals, uint256) / 10 ** convert(DECIMALS, uint256)  # NOTE: Assume 1:1 price if nothing deposited yet

    # transfer assets from msg.sender first...
    self.asset.transferFrom(msg.sender, self, assets)
    # ... and deposit in desk
    self._deposit_desk(assets)

    self.totalSupply += _shares
    self.balanceOf[_receiver] += _shares
    log Transfer(empty(address), _receiver, _shares)
    log Deposit(msg.sender, _receiver, assets, _shares)
    return assets


@view
@external
def maxWithdraw(_owner: address) -> uint256:
    """
    @notice We apply no restrictions on the amount of the underlying asset that can be withdrawn
    @param _owner The address of the balance owner
    @return The full balance of owner
    """

    return self._convertToAssets(self.balanceOf[_owner])


@view
@external
def previewWithdraw(_assets: uint256) -> uint256:
    """
    @notice Calculate the number of shares that would be burned if a certain amount of underlying asset is withdrawn
    @param _assets The number of asset tokens to withdraw
    @return The number of shares that would be burned
    """

    shares: uint256 = self._convertToShares(_assets)

    # NOTE: Vyper does lazy eval on if, so this avoids SLOADs most of the time
    if shares * 10 ** convert(self.asset_decimals, uint256) == _assets * 10 ** convert(DECIMALS, uint256) and self.totalSupply == 0:
        return 0  # NOTE: Nothing to redeem

    return shares

@internal
def _withdraw_desk(_assets: uint256):
    """
    @dev Call the desk's withdraw function
    @param _assets The amount of the desk's base coin to be withdrawn
    """

    assert self.desk.total_liquidity() >= _assets
    self.desk.withdraw(_assets)

@external
@nonreentrant('lock')
def withdraw(_assets: uint256, _receiver: address=msg.sender, _owner: address=msg.sender) -> uint256:
    """
    @notice Withdraw specified number of underlying asset. If msg.sender is not _owner, then _owner must approve msg.sender for shares amount _assets converts to first. Reverts if total available liquidity in the desk is less than _assets
    @param _assets The amount of underlying asset to withdraw
    @param _receiver The address to which withdrawn amount is transferred
    @param _owner The address that owns the shares
    @return The number of shares burnt
    """

    shares: uint256 = self._convertToShares(_assets)

    # NOTE: Vyper does lazy eval on if, so this avoids SLOADs most of the time
    if shares * 10 ** convert(self.asset_decimals, uint256) == _assets * 10 ** convert(DECIMALS, uint256) and self.totalSupply == 0:
        raise  # Nothing to redeem

    if _owner != msg.sender:
        self.allowance[_owner][msg.sender] -= shares

    self.totalSupply -= shares
    self.balanceOf[_owner] -= shares

    self._withdraw_desk(_assets)

    self.asset.transfer(_receiver, _assets)
    log Transfer(_owner, empty(address), shares)
    log Withdraw(msg.sender, _receiver, _owner, _assets, shares)
    return shares


@view
@external
def maxRedeem(_owner: address) -> uint256:
    """
    @notice We set no restrictions on the number of shares that can be redeemed
    @param _owner The address that owns the shares
    @return The full balance of owner
    """

    return self.balanceOf[_owner]


@view
@external
def previewRedeem(_shares: uint256) -> uint256:
    """
    @notice Calculate the amount of assets that can be obtained by redeeming _shares
    @param _shares The number of shares
    @return The number of asset tokens
    """

    return self._convertToAssets(_shares)


@external
@nonreentrant('lock')
def redeem(_shares: uint256, _receiver: address=msg.sender, _owner: address=msg.sender) -> uint256:
    """
    @notice Burn specified shares and transfer underlying asset tokens to _receiver. If msg.sender is not _owner, then _owner must approve msg.sender for shares amount first. Reverts if total available liquidity in the desk is less than the amount of assets _shares converts to
    @param _shares The number of shares to be redeemed
    @param _receiver The address to receive the transferred asset tokens
    @param _owner The address of the shares owner
    @return The number of asset tokens transferred
    """

    if _owner != msg.sender:
        self.allowance[_owner][msg.sender] -= _shares

    assets: uint256 = self._convertToAssets(_shares)
    # burn shares
    self.totalSupply -= _shares
    self.balanceOf[_owner] -= _shares

    # transfer asset from the desk to self...
    self._withdraw_desk(assets)
    # ... on to _receiver
    self.asset.transfer(_receiver, assets)

    # burn event
    log Transfer(_owner, empty(address), _shares)
    log Withdraw(msg.sender, _receiver, _owner, assets, _shares)
    return assets
