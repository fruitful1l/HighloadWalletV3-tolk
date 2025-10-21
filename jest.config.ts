import type { Config } from 'jest';

const config: Config = {
    preset: 'ts-jest',
    globalSetup: './jest.setup.ts',
    cache: false, // disabled caching to prevent old Tact files from being used after a rebuild
    testEnvironment: '@ton/sandbox/jest-environment',
    testPathIgnorePatterns: ['/node_modules/', '/dist/'],
    reporters: [
        'default',
        ['@ton/sandbox/jest-reporter', {
            // options
            snapshotDir: '.snapshot',              // output folder for benchmark reports, default: '.snapshot'
            contractDatabase: 'contract.abi.json', // path or json a map of known contracts, see Collect metric API, default: 'contract.abi.json'
            reportName: 'gas-report',              // report name, default: 'gas-report'
            depthCompare: 2,                       // comparison depth, default: 2
            removeRawResult: true,                 // remove raw metric file, default: true
            contractExcludes: [                    // exclude specific contracts from snapshot, default: []
                'TreasuryContract',
            ],
        }],
    ],
};

export default config;
