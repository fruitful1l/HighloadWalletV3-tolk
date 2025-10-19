import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Cell, toNano } from '@ton/core';
import { HighloadWallet } from '../wrappers/HighloadWallet';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';

describe('HighloadWallet', () => {
    let code: Cell;

    beforeAll(async () => {
        code = await compile('HighloadWallet');
    });

    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let highloadWallet: SandboxContract<HighloadWallet>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        highloadWallet = blockchain.openContract(HighloadWallet.createFromConfig({}, code));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await highloadWallet.sendDeploy(deployer.getSender(), toNano('0.05'));

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: highloadWallet.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and highloadWallet are ready to use
    });
});
