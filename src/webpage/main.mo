import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Prim "mo:⛔";
import Prelude "mo:base/Prelude";
import HTTP "./lib/HTTP";
import Bool "mo:base/Bool";

actor {
    public type HttpRequest = HTTP.HttpRequest;
    public type HttpResponse = HTTP.HttpResponse;
    public type StreamingCallbackResponse = HTTP.StreamingCallbackResponse;
    public type StreamingCallbackToken = HTTP.StreamingCallbackToken;
    type HeaderField = HTTP.HeaderField;
    // For now, we're not going to be processing gzip encoding as we don't have a library in motoko to encode/decode.
    let checkGzip : Bool = false;
    stable var counter : Nat = 0;
    stable var page_title : Text = "Motoko Bootcamp 2023";

    // dfx canister call webpage increment
    public func increment() : async () {
        counter += 1
    };

    // dfx canister call webpage getValue
    public query func getValue() : async Nat {
        counter
    };

    func isGzip(x : HeaderField) : Bool {
        checkGzip and Text.map(x.0, Prim.charToLower) == "accept-encoding" and Text.contains(Text.map(x.1, Prim.charToLower), #text "gzip")
    };

    public query func http_request(req : HttpRequest) : async HttpResponse {
        switch (req.method, not Option.isNull(Array.find(req.headers, isGzip)), req.url) {
            case ("GET", false, "/stream") {
                {
                    status_code = 200 : Nat16;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8("Counter");
                    streaming_strategy = ?#Callback({
                        callback = http_streaming;
                        token = {
                            content_encoding = "";
                            index = 0;
                            key = "start";
                        }
                    });
                    upgrade = ?false
                }
            };
            case ("GET", false, _) {
                {
                    status_code = 200;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8("Counter is " # Nat.toText(counter) # "\n" # req.url # "\n");
                    streaming_strategy = null;
                    upgrade = null
                }
            };
            case ("GET", true, _) {
                // Return gzip encoded content.
                {
                    status_code = 200;
                    headers = [("content-type", "text/plain"), ("content-encoding", "gzip")];
                    // No library to do this at the moment in motoko, so this is manual input.
                    body = "\1f\8b\08\00\98\02\1b\62\00\03\2b\2c\4d\2d\aa\e4\02\00\d6\80\2b\05\06\00\00\00";
                    streaming_strategy = null;
                    upgrade = null
                }
            };

            case ("POST", _, _) {
                {
                    status_code = 204;
                    headers = [];
                    body = "";
                    streaming_strategy = null;
                    upgrade = ?true
                }
            };
            case _ {
                {
                    status_code = 400;
                    headers = [];
                    body = "Invalid request";
                    streaming_strategy = null;
                    upgrade = null
                }
            }
        }
    };

    public func http_request_update(req : HttpRequest) : async HttpResponse {
        switch (req.method, not Option.isNull(Array.find(req.headers, isGzip))) {
            case ("POST", false) {
                counter += 1;
                {
                    status_code = 201;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8("Counter updated to " # Nat.toText(counter) # "\n");
                    streaming_strategy = null;
                    upgrade = null
                }
            };
            case ("POST", true) {
                counter += 1;
                {
                    status_code = 201;
                    headers = [("content-type", "text/plain"), ("content-encoding", "gzip")];
                    body = "\1f\8b\08\00\37\02\1b\62\00\03\2b\2d\48\49\2c\49\e5\02\00\a8\da\91\6c\07\00\00\00";

                    streaming_strategy = null;
                    upgrade = null
                }
            };
            case _ {
                {
                    status_code = 400;
                    headers = [];
                    body = "Invalid request";
                    streaming_strategy = null;
                    upgrade = null
                }
            }
        }
    };

    public query func http_streaming(token : StreamingCallbackToken) : async StreamingCallbackResponse {
        switch (token.key) {
            case "start" {
                {
                    body = Text.encodeUtf8(" is ");
                    token = ?{ content_encoding = token.content_encoding; index = token.index; key = "next"; }
                }
            };
            case "next" {
                {
                    body = Text.encodeUtf8(Nat.toText(counter));
                    token = ?{ content_encoding = token.content_encoding; index = token.index; key = "last"; }
                }
            };
            case "last" {
                {
                    body = Text.encodeUtf8(" streaming\n");
                    token = null
                }
            };
            case _ { Prelude.unreachable() }
        }
    }
}
