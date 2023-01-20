import { writable } from 'svelte/store'

export const view = writable({
    home: 1,
    view: 2,
    create: 3,
    vote: 4,
    current: 1,
});

export const proposalToVote = writable({
    proposalID: "null"
});

export const hasVoted = writable(false);
export const isAuthenticated = writable(false);
export const accountId = writable(null);
// Returns "@dfinity/principal";
export const principal = writable(null);
export const principalId = writable(null);
// Plug sample return:
// {agent: Nt, principalId: 'bi3lr-cwsga-wc4qg-ypqug-mkn4l-2l436-yxpkm-dozec-ah3nq-qmjqo-lae', accountId: '18235dcaa87a03c8744dce0656324c46c440ad6782c3dc3af5a7dccbdecb9d7e'}
export const authSessionData = writable(null);
export const daoActor = writable(null);
export const webpageActor = writable(null);