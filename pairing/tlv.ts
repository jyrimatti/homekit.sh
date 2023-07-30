
// from: https://github.com/homebridge/HAP-NodeJS/tree/master/src/lib/util


const EMPTY_TLV_TYPE = 0x00; // and empty tlv with id 0 is usually used as delimiter for tlv lists

/**
 * @group TLV8
 */
export type TLVEncodable = Buffer | number | string;

/**
 * @group TLV8
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function encode(type: number, data: TLVEncodable | TLVEncodable[], ...args: any[]): Buffer {
  const encodedTLVBuffers: Buffer[] = [];

  // coerce data to Buffer if needed
  if (typeof data === "number") {
    data = Buffer.from([data]);
  } else if (typeof data === "string") {
    data = Buffer.from(data);
  }

  if (Array.isArray(data)) {
    let first = true;
    for (const entry of data) {
      if (!first) {
        encodedTLVBuffers.push(Buffer.from([EMPTY_TLV_TYPE, 0])); // push delimiter
      }

      first = false;
      encodedTLVBuffers.push(encode(type, entry));
    }

    if (first) { // we have a zero length array!
      encodedTLVBuffers.push(Buffer.from([type, 0]));
    }
  } else if (data.length <= 255) {
    encodedTLVBuffers.push(Buffer.concat([Buffer.from([type,data.length]),data]));
  } else { // otherwise it doesn't fit into one tlv entry, thus we push multiple
    let leftBytes = data.length;
    let currentIndex = 0;

    for (; leftBytes > 0;) {
      if (leftBytes >= 255) {
        encodedTLVBuffers.push(Buffer.concat([Buffer.from([type, 0xFF]), data.slice(currentIndex, currentIndex + 255)]));
        leftBytes -= 255;
        currentIndex += 255;
      } else {
        encodedTLVBuffers.push(Buffer.concat([Buffer.from([type,leftBytes]), data.slice(currentIndex)]));
        leftBytes -= leftBytes;
      }
    }
  }

  // do we have more arguments to encode?
  if (args.length >= 2) {

    // chop off the first two arguments which we already processed, and process the rest recursively
    const [ nextType, nextData, ...nextArgs ] = args;
    const remainingTLVBuffer = encode(nextType, nextData, ...nextArgs);

    // append the remaining encoded arguments directly to the buffer
    encodedTLVBuffers.push(remainingTLVBuffer);
  }

  return Buffer.concat(encodedTLVBuffers);
}

/**
 * This method is the legacy way of decoding tlv data.
 * It will not properly decode multiple list of the same id.
 * Should the decoder encounter multiple instances of the same id, it will just concatenate the buffer data.
 *
 * @param buffer - TLV8 data
 *
 * Note: Please use {@link decodeWithLists} which properly decodes list elements.
 *
 * @group TLV8
 */
export function decode(buffer: Buffer): Record<number, Buffer> {
  const objects: Record<number, Buffer> = {};

  let leftLength = buffer.length;
  let currentIndex = 0;

  for (; leftLength > 0;) {
    const type = buffer[currentIndex];
    const length = buffer[currentIndex + 1];
    currentIndex += 2;
    leftLength -= 2;

    const data = buffer.slice(currentIndex, currentIndex + length);

    if (objects[type]) {
      objects[type] = Buffer.concat([objects[type],data]);
    } else {
      objects[type] = data;
    }

    currentIndex += length;
    leftLength -= length;
  }

  return objects;
}
