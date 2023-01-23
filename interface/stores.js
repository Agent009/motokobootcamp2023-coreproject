import { writable } from 'svelte/store'

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:   ENVIRONMENT   ----------   ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

export const isDevelopmentEnv = process.env.NODE_ENV === "development";
//TODO : Add mainnet canister ids when deployed on the IC
export const daoCanisterId = isDevelopmentEnv ? "rrkah-fqaaa-aaaaa-aaaaq-cai" : "6bcmp-xyaaa-aaaap-qa5mq-cai"
export const webpageCanisterId = isDevelopmentEnv ? "ryjl3-tyaaa-aaaaa-aaaba-cai" : "6pabh-miaaa-aaaap-qa5nq-cai"
export const HOST = isDevelopmentEnv ? "http://localhost:3000/" : "https://ic0.app";

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:    NAVIGATION   ----------   ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

export const view = writable({
    home: 1,
    view: 2,
    create: 3,
    vote: 4,
    current: 1,
});

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:       AUTH      ----------   ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

export const isAuthenticated = writable(false);
export const accountId = writable(null);
// Returns "@dfinity/principal";
export const principal = writable(null);
export const principalId = writable(null);
// Plug sample return:
// {agent: Nt, principalId: 'bi3lr-cwsga-wc4qg-ypqug-mkn4l-2l436-yxpkm-dozec-ah3nq-qmjqo-lae', accountId: '18235dcaa87a03c8744dce0656324c46c440ad6782c3dc3af5a7dccbdecb9d7e'}
export const authSessionData = writable(null);

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:    APP LOGIC    ----------   ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

export const proposalToVote = writable({proposalID: "null"});
export const voteTokens = writable(100000);
export const hasVoted = writable(false);
export const mbtTokens = writable(0);
export const daoActor = writable(null);
export const webpageActor = writable(null);

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:      SYSTEM       PARAMS     ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

export const transferFee = writable(null);
export const proposalVoteThreshold = writable(null);
export const proposalSubmissionDeposit = writable(null);