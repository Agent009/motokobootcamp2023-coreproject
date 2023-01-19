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