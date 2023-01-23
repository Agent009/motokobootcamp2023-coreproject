import { get } from "svelte/store"
import { Principal } from "@dfinity/principal";
import { isAuthenticated, principal, principalId, daoActor, webpageActor, daoCanisterId, webpageCanisterId } from "./stores"
import { idlFactory } from "../src/declarations/dao"

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:     API CALLS   ----------   ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

/**
 * Get the system parameters.
 */
export async function getSystemParams(dao) {
	if (!dao) {
		// console.log("getSystemParams --- daoActor not provided.")
		return;
	}

	console.log("ASYNC --- getSystemParams")
	let response;

	try {
		// Fetch the response and handle it in async fashion so we don't get the promise errors in console.
		response = await dao
			.get_system_params()
			.then((resp) => {
				console.log("getSystemParams - response: ", resp);
				return resp;
			})
			.catch((error) => {
				console.log("Error getSystemParams (1) - ", error);
				throw new Error(error);
			})
	} catch (error) {
		// Catch-all in case something else goes wrong.
		console.log("Error getSystemParams (2) - ", error);
		throw new Error(error);
	}

	return response;
}

/**
 * Get the staken tokens.
 */
export async function getStakedTokens(dao) {
	console.log("EVENT --- get_staked_tokens")
	let response

	if (!dao) {
		return
	}

	try {
		// Fetch the response and handle it in async fashion so we don't get the promise errors in console.
		response = await dao.get_staked_tokens()
			.then((resp) => {
				console.log("get_staked_tokens - ", resp)

				if (resp.ok) {
					return resp.ok
				} else {
					throw new Error(resp.err)
				}
			})
			.catch((error) => {
				console.log("Error get_staked_tokens (1) - ", error)
				throw new Error(error)
			})
	} catch (error) {
		// Catch-all in case something else goes wrong.
		console.log("Error get_staked_tokens (2) - ", error)
		throw new Error(error)
	}

	return response
}

/**
 * Get the user's MBT tokens.
 */
export async function getMBTTokens(dao) {
	// let dao = get(daoActor);

	if (!dao) {
		console.log("getMBTTokens --- daoActor not provided.")
		return;
	}

	console.log("ASYNC --- getMBTTokens")
	let response;

	try {
		// Fetch the response and handle it in async fashion so we don't get the promise errors in console.
		response = await dao.get_mbt_tokens()
			.then((resp) => {
				console.log("getMBTTokens - response: ", resp);
				return resp;
			})
			.catch((error) => {
				console.log("Error getMBTTokens (1) - ", error);
				throw new Error(error);
			})
	} catch (error) {
		// Catch-all in case something else goes wrong.
		console.log("Error getMBTTokens (2) - ", error);
		throw new Error(error);
	}

	return response;
}

/**
 * Get all the proposals
 */
export async function getAllProposals(dao) {
	if (!dao) {
		return
	}

	let res;
	console.log("get_all_proposals");

	try {
		res = await dao.get_all_proposals()
	} catch (error) {
		console.log("Error getting all proposals", error);
		throw new Error(error)
	}

	console.log("Proposals", res)
	return res
}

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:   CONVERSIONS   ----------   ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

/**
 * Encode in UTF8 bytes
 * @param {string} text 
 * @returns 
 */
export function encodeUtf8(text) {
	const arr = [];

	for (const char of text) {
		const codepoint = char.codePointAt(0);

		if (codepoint < 128) {
			arr.push(codepoint);
			continue;
		}

		if (codepoint < 2048) {
			const num1 = 0b11000000 | (codepoint >> 6);
			const num2 = 0b10000000 | (codepoint & 0b111111);

			arr.push(num1, num2);
			continue;
		}

		if (codepoint < 65536) {
			const num1 = 0b11100000 | (codepoint >> 12);
			const num2 = 0b10000000 | ((codepoint >> 6) & 0b111111);
			const num3 = 0b10000000 | (codepoint & 0b111111);

			arr.push(num1, num2, num3);
			continue;
		}

		const num1 = 0b11110000 | (codepoint >> 18);
		const num2 = 0b10000000 | ((codepoint >> 12) & 0b111111);
		const num3 = 0b10000000 | ((codepoint >> 6) & 0b111111);
		const num4 = 0b10000000 | (codepoint & 0b111111);

		arr.push(num1, num2, num3, num4);
	}

	return arr;
}

/**
 * Decode from UTF8 bytes
 * @param {*} bytes 
 * @returns 
 */
export function decodeUtf8(bytes) {
	const arr = [];

	for (let i = 0; i < bytes.length; i++) {
		const byte = bytes[i];

		if (!(byte & 0b10000000)) {
			const char = String.fromCodePoint(byte);
			arr.push(char);
			continue;
		}

		let codepoint, byteLen;

		if (byte >> 5 === 0b110) {
			codepoint = 0b11111 & byte;
			byteLen = 2;
		} else if (byte >> 4 === 0b1110) {
			codepoint = 0b1111 & byte;
			byteLen = 3;
		} else if (byte >> 3 === 0b11110) {
			codepoint = 0b111 & byte;
			byteLen = 4;
		} else {
			// this is invalid UTF-8 or we are in middle of a character
			throw new Error('found invalid UTF-8 byte ' + byte);
		}

		for (let j = 1; j < byteLen; j++) {
			const num = 0b00111111 & bytes[j + i];
			const shift = 6 * (byteLen - j - 1);
			codepoint |= num << shift;
		}

		const char = String.fromCodePoint(codepoint)
		arr.push(char);
		i += byteLen - 1;
	}

	return arr.join('');
}

/**
 * Convert a string to a candid blob representation
 * // In Chrome DevTools:
 * 	const textBlob = new Blob(["Updated page title"], {type: 'text/plain'});
 * 	const byteArray = await [...new Uint8Array(await textBlob.arrayBuffer())]
 * 	byteArray
 * @param {string} text The string to convert
 * @returns {Uint8Array}
 */
export async function textToUnit8Array(text) {
	const textBlob = new Blob([text], { type: 'text/plain' });
	return [...new Uint8Array(await textBlob.arrayBuffer())];
}

//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
//  REGION:       MISC      ----------   ----------   ----------   ----------   ----------   ----------
//----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

export function getFormattedToken(amount) {
	//if x is a string/non-number, use parseInt/parseFloat to convert to a number.
	let value = Number(amount);

	if (Number.isNaN(value)) {
		return 0 + " MBT";
	}

	return value.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 0 }) + " MBT";
}