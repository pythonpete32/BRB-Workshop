import {
  Client,
  Context,
  CreateDaoParams,
  DaoCreationSteps,
} from '@aragon/sdk-client';
import {PluginInstallItem, hexToBytes} from '@aragon/sdk-client-common';
import {Wallet} from 'ethers';
import {defaultAbiCoder} from 'ethers/lib/utils';
import {MultisigPluginInstallParams, MultisigClient} from '@aragon/sdk-client';

import dotenv from 'dotenv';
dotenv.config();

// DAO params
const DAOName = 'brb-test-4206912';
const network = 'goerli';

// multisig params
const minAppovals = 1;
const members = ['0x47d80912400ef8f8224531EBEB1ce8f2ACf4b75a'];

// Vault params
const vaultRepoAddress = '0x713FE64E6cc1750931A724D2E8EE6192d7472Fd6';
const mockDaiAddress = '0xFA56c4AF9C7A4c041846bA7B5F0178B5671f33eC';

// SDK params
const wallet = new Wallet(process.env.PRIVATE_KEY!);
const context = new Context({
  network: network,
  signer: wallet,
  web3Providers: [`https://goerli.infura.io/v3/${process.env.API_KEY_INFURA}`],
});

const client = new Client(context);

async function main() {
  // Encodes the parameters of the Multisig plugin
  const multisigPluginIntallParams: MultisigPluginInstallParams = {
    votingSettings: {
      minApprovals: minAppovals,
      onlyListed: true,
    },
    members: members,
  };

  const multisigPluginInstallItem: PluginInstallItem =
    MultisigClient.encoding.getPluginInstallItem(
      multisigPluginIntallParams,
      network
    );

  // Manually encoding the parameters for the Vault plugin
  const encodedVaultInstallParams = defaultAbiCoder.encode(
    ['address'],
    [mockDaiAddress]
  );

  const VaultPluginInstallItem: PluginInstallItem = {
    id: vaultRepoAddress,
    data: hexToBytes(encodedVaultInstallParams),
  };

  // Pin metadata for the DAO to IPFS
  const metadataUri: string = await client.methods.pinMetadata({
    name: 'My DAO',
    description: 'This is a description',
    avatar: '',
    links: [
      {
        name: 'Web site',
        url: 'https://...',
      },
    ],
  });

  // put it all together and for the createDao params
  const createParams: CreateDaoParams = {
    metadataUri,
    ensSubdomain: DAOName, // my-org.dao.eth
    plugins: [multisigPluginInstallItem, VaultPluginInstallItem],
  };

  // Creates a DAO with a Multisig plugin installed.
  const steps = client.methods.createDao(createParams);
  for await (const step of steps) {
    try {
      switch (step.key) {
        case DaoCreationSteps.CREATING:
          console.log({txHash: step.txHash});
          break;
        case DaoCreationSteps.DONE:
          console.log({
            daoAddress: step.address,
            pluginAddresses: step.pluginAddresses,
          });
          break;
      }

      console.log(
        `https://app.aragon.org/#/daos/goerli/${DAOName}.dao.eth/dashboard`
      );
    } catch (err) {
      console.error(err);
    }
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
