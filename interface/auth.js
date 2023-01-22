import { get } from "svelte/store"
import { isAuthenticated, accountId, principal, principalId, authSessionData, daoActor, webpageActor } from "./stores"
import { idlFactory as idlFactoryDAO } from "../src/declarations/dao/dao.did.js"
import { idlFactory as idlFactoryWeb } from "../src/declarations/webpage/webpage.did.js"
import { Actor, HttpAgent } from "@dfinity/agent";
import { AuthClient } from '@dfinity/auth-client';

//region Plug Wallet Auth
//TODO : Add mainnet canister ids when deployed on the IC
const daoCanisterId = process.env.NODE_ENV === "development" ? "rrkah-fqaaa-aaaaa-aaaaq-cai" : "rvpd5-iqaaa-aaaaj-qazsa-cai"
const webpageCanisterId = process.env.NODE_ENV === "development" ? "ryjl3-tyaaa-aaaaa-aaaba-cai" : "rvpd5-iqaaa-aaaaj-qazsa-cai"
const HOST = process.env.NODE_ENV === "development" ? "http://localhost:3000/" : "https://ic0.app";
const whitelist = [daoCanisterId, webpageCanisterId];

// export const isLoggedIn = await window.ic.plug.isConnected();

export const verifyConnectionAndAgent = async () => {
  const connected = await window.ic.plug.isConnected();

  if (!connected) await login();

  if (connected && !window.ic.plug.agent) {
    console.log("Connected but no agent found. Creating agent for host: ", HOST);
    window.ic.plug.createAgent({ whitelist, HOST })
  }
};

// Callback to print sessionData
const onConnectionUpdate = () => {
  console.log("Connection update callback:", window.ic.plug.sessionManager.sessionData)
}

// See https://docs.plugwallet.ooo/
// https://github.com/Psychedelic/plug-inpage-provider/blob/develop/src/Provider/index.ts
export async function balance(symbol) {
  console.log("Attempting to get balance:", principal)
  // (3) [{…}, {…}, {…}]
  // 0:  {symbol: 'ICP', canisterId: 'ryjl3-tyaaa-aaaaa-aaaba-cai', name: 'ICP', decimals: 8, standard: 'ROSETTA', …}
  // 1: {symbol: 'XTC', canisterId: 'aanaa-xaaaa-aaaah-aaeiq-cai', name: 'Cycles', decimals: 12, standard: 'XTC', …}
  // 2: {symbol: 'WICP', canisterId: 'utozz-siaaa-aaaam-qaaxq-cai', name: 'Wrapped ICP', decimals: 8, standard: 'WICP', …}
  try {
    let balances = await window.ic.plug.requestBalance();

    if (balances) {
      console.log("Got balances: ", balances);

      for (let i in balances) {
        let entry = balances[i]
        // console.log(entry);

        if (entry.symbol === symbol) {
          // console.log("For", symbol, "balance is", entry);
          return entry
        }
      }
    }
  } catch (err) {
    console.log("There was an error trying to fetch your balances. ", err);
  }

  return 0;
}

export async function logout() {
  console.log("Attempting to logout:", principal)
  await window.ic.plug.disconnect();
}

export async function login() {
  console.log("Attempting to login")
  const result = await window.ic.plug.requestConnect({
    whitelist: whitelist,
    host: HOST,
    onConnectionUpdate
  })

  if (!result) {
    throw new Error("User denied the connection.")
  }

  console.log(`The connected user's public key is:`, result);
  const p = await window.ic.plug.agent.getPrincipal()
  const agent = new HttpAgent({
    host: HOST,
  });

  if (process.env.NODE_ENV === "development") {
    agent.fetchRootKey();
  }

  const dao = Actor.createActor(idlFactoryDAO, {
    agent,
    canisterId: daoCanisterId,
  });
  const webpage = Actor.createActor(idlFactoryWeb, {
    agent,
    canisterId: webpageCanisterId,
  });

  /*const dao = await window.ic.plug.createActor({
    canisterId: daoCanisterId,
    interfaceFactory: idlFactoryDAO,
  })
  const webpage = await window.ic.plug.createActor({
    canisterId: webpageCanisterId,
    interfaceFactory: idlFactoryWeb,
  })*/

  isAuthenticated.set(() => true)
  accountId.update(() => window.ic.plug.accountId)
  principal.update(() => p)
  principalId.update(() => p.toLocaleString())
  authSessionData.update(() => window.ic.plug.sessionManager.sessionData)
  daoActor.update(() => dao)
  webpageActor.update(() => webpage)
  console.log("Stores set.", "isAuthenticated", get(isAuthenticated), "accountId", get(accountId), "principal", get(principal), "principalId", get(principalId));
  console.log("authSessionData", get(authSessionData));
}

// access session principalId
// export const userPrincipal = window.ic.plug.principalId
// access session accountId
// export const userAccountId = window.ic.plug.accountId
// access session agent
// export const authAgent = window.ic.plug.agent
// export const authSessionData = window.ic.plug.sessionManager.sessionData
//endregion

//region Internet Identity Auth
/*const IDENTITY_PROVIDER = "https://identity.ic0.app/#authorize";

export const login = async () => {
    const authClient = await AuthClient.create();
    const isAuthenticated = await authClient.isAuthenticated();

    if (isAuthenticated) {
        await handleAuthenticated(authClient);
    } else {
        console.log("Not logged in.");
        // Call authClient.login(...) to login with Internet Identity. This will open a new tab
        // with the login prompt. The code has to wait for the login process to complete.
        // We can either use the callback functions directly or wrap in a promise.
        await authClient.login({
            // 7 days in nanoseconds
            maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
            identityProvider: IDENTITY_PROVIDER,
            onSuccess: async () => {
                handleAuthenticated(authClient);
            }
        });
    }
}

async function handleAuthenticated(authClient) {
    // Get the identity from the auth client:
    const identity = authClient.getIdentity();
    const userPrincipal = identity.getPrincipal();
    // console.log(userPrincipal);
    console.log("Logged in with principal:", userPrincipal.toLocaleString());
    console.log("Principal:", userPrincipal.toLocaleString(), "Anonymous:", userPrincipal.isAnonymous());
}*/
//endregion
