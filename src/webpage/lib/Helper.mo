import Blob "mo:base/Blob";
import Text "mo:base/Text";
import HTTP "./HTTP";

module Helper {
  public type HttpRequest = HTTP.HttpRequest;
  public type DecodedHttpRequest = HTTP.DecodedHttpRequest;

  // Decode the request body
  public func decodeRequestBody(request : HttpRequest) : DecodedHttpRequest {
    { request with body = decodeUtf8(request.body) }
  };

  public func encodeUtf8(input : Text) : Blob {
    Text.encodeUtf8(input)
  };

  public func decodeUtf8(input : Blob) : Text {
    switch (Text.decodeUtf8(input)) {
      // If decoding the body gives us nothing, then send back the request with an empty body string.
      case null { "" };
      // Otherwise, send back the request with the decoded body string.
      case (?decoded) { decoded }
    };
  };
}
