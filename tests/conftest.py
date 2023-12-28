import pytest
import json
from ape import project, accounts

@pytest.fixture
def desks_data(scope='module'):
    with open('./tests/desks.json') as fp:
        desks_data = json.load(fp)

    return desks_data

@pytest.fixture
def crayon_desk(Contract, desks_data, accounts):
    def crayon_desk(token):
        # impersonate a big holder of the token
        holder = accounts[desks_data[token]['holder']]
        # give holder some ETH
        holder.balance += int(1e18)
        # point to the token contract
        token_contract = Contract(desks_data[token]['token'])
        balance = token_contract.balanceOf(holder)
        # accounts[1]/[2] will serve as our lenders in the tests
        token_contract.transfer(accounts[1], balance // 2, sender=holder)
        token_contract.transfer(accounts[2], balance // 2, sender=holder)

        upperTok = token.upper()
        # accounts[0] serves as our admin
        return project.Desk4626.deploy(desks_data[token]['desk'], 'xc' + upperTok, 'Crayon '+ upperTok, sender=accounts[0])

    yield crayon_desk
