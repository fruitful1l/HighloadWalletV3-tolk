import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type HighloadWalletConfig = {};

export function highloadWalletConfigToCell(config: HighloadWalletConfig): Cell {
    return beginCell().endCell();
}

export class HighloadWallet implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new HighloadWallet(address);
    }

    static createFromConfig(config: HighloadWalletConfig, code: Cell, workchain = 0) {
        const data = highloadWalletConfigToCell(config);
        const init = { code, data };
        return new HighloadWallet(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }
}
