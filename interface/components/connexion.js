import { principal } from "../stores"
import { daoActor } from "../stores"
import { webpageActor } from "../stores"
import { idlFactory as idlFactoryDAO } from "../../src/declarations/dao/dao.did.js"
import { idlFactory as idlFactoryWebpage } from "../../src/declarations/webpage/webpage.did.js"

//TODO : Add your mainnet id whenever you have deployed on the IC
const daoCanisterId = process.env.NODE_ENV === "development" ? "rrkah-fqaaa-aaaaa-aaaaq-cai" : "rvpd5-iqaaa-aaaaj-qazsa-cai"
const webpageCanisterId = process.env.NODE_ENV === "development" ? "ryjl3-tyaaa-aaaaa-aaaba" : "rvpd5-iqaaa-aaaaj-qazsa-cai"

// See https://docs.plugwallet.ooo/ for more informations
export async function plugConnection() {
  const result = await window.ic.plug.requestConnect({
    whitelist: [daoCanisterId, webpageCanisterId],
  })

  if (!result) {
    throw new Error("User denied the connection")
  }
  
  const p = await window.ic.plug.agent.getPrincipal()
  const dao = await window.ic.plug.createActor({
    canisterId: daoCanisterId,
    interfaceFactory: idlFactoryDAO,
  })
  const webpage = await window.ic.plug.createActor({
    canisterId: webpageCanisterId,
    interfaceFactory: idlFactoryWebpage,
  })

  principal.update(() => p)
  daoActor.update(() => dao)
  webpageActor.update(() => webpage)
}
