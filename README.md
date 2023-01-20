# ICP Motoko Bootcamp 2023 - Core Project - DAO

A DAO to control the text on a webpage through proposals.

Contains three canisters:

1. A `dao` canister (Motoko) for managing the logic of the DAO.
2. A `webpage` canister (Motoko) for storing the webpage that the DAO will control.
3. A interface canister (Svelte) (folder called `interface`) for the user-friendly interface of the DAO.

On-chain UI: TBD

## Running the project locally

To test the project locally, use the following commands:

```bash
# Set rust backtrace to get more useful debug info when things go wrong
export RUST_BACKTRACE=full

# Starts the replica, running in the background
dfx start --clean --background

# First time, canisters will need to be created, built and the back-end deployed and the declarations generated.
npm run create
npm run backend

# Then, the interface can be deployed
npm run interface

# Deploys the canisters to the replica and generates the candid interface
dfx deploy
```

Once the job completes, the application will be available at `http://localhost:4943?canisterId={asset_canister_id}`.

Additionally, if you are making frontend changes, you can start a development server with

```bash
npm run dev
```

Which will start a server at `http://localhost:8080`, proxying API requests to the replica at port 4943.

### Note on frontend environment variables

If you are hosting frontend code somewhere without using DFX, you may need to make one of the following adjustments to ensure your project does not fetch the root key in production:

- set`NODE_ENV` to `production` if you are using Webpack
- use your own preferred method to replace `process.env.NODE_ENV` in the autogenerated declarations
- Write your own `createActor` constructor

## Useful commands

* Check on-chain balance: `dfx wallet --network=ic balance`
* Get principal ID: `dfx identity get-principal`
* Get ledger ID: `dfx ledger account-id`
* Get on-chain wallet ID: `dfx identity --network=ic get-wallet`

# Resources

- [Project Requirements & Specification](https://github.com/motoko-bootcamp/motokobootcamp-2023/blob/main/core_project/PROJECT.MD)
- [Quick Start](https://internetcomputer.org/docs/current/developer-docs/quickstart/hello10mins)
- [SDK Developer Tools](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove)
- [Motoko Programming Language Guide](https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity/motoko/)
- [Motoko Language Quick Reference](https://internetcomputer.org/docs/current/references/motoko-ref/)
- [JavaScript API Reference](https://erxue-5aaaa-aaaab-qaagq-cai.raw.ic0.app)
