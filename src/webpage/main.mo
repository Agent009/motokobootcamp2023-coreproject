import CertifiedData "mo:base/CertifiedData";
import Cycles "mo:base/ExperimentalCycles";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Prim "mo:⛔";
import Prelude "mo:base/Prelude";
import Bool "mo:base/Bool";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import HTTP "./lib/HTTP";
import { encodeUtf8; decodeUtf8; decodeRequestBody } "./lib/Helper";

shared ({ caller = creator }) actor class Webpage() = {
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:       TYPES     ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    public type HttpRequest = HTTP.HttpRequest;
    public type DecodedHttpRequest = HTTP.DecodedHttpRequest;
    public type HttpResponse = HTTP.HttpResponse;
    public type StreamingCallbackResponse = HTTP.StreamingCallbackResponse;
    public type StreamingCallbackToken = HTTP.StreamingCallbackToken;
    type HeaderField = HTTP.HeaderField;
    type CertifiedCounter = {
        certificate : ?Blob;
        value : Nat;
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:    VARIABLES    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    stable var admins : [Principal] = [creator];
    // For now, we're not going to be processing gzip encoding as we don't have a library in motoko to encode/decode.
    let checkGzip : Bool = false;
    stable var counter : Nat = 0;
    let pattern_pt = #text "page_title = ";
    let pattern_pc = #text "page_contents = ";
    stable var page_title : Text = "Motoko Bootcamp 2023";
    stable var page_content : Text = "Motoko Bootcamp 2023";

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:     ENCODING     DECODING    ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // dfx canister call webpage encodeInputToUtf8 '("page_content = \"1\"")'
    // Gives: (blob "page_content = \221\22")
    // Gives: (vec {112; 97; 103; 101; 95; 99; 111; 110; 116; 101; 110; 116; 32; 61; 32; 34; 49; 34})
    public query func encodeInputToUtf8(input : Text) : async Blob {
        encodeUtf8(input)
    };

    // dfx canister call webpage decodeUtf8Input '(vec {112; 97; 103; 101; 95; 99; 111; 110; 116; 101; 110; 116; 32; 61; 32; 34; 49; 34})'
    // Gives: ("page_content = \"1\"")
    public query func decodeUtf8Input(input : Blob) : async Text {
        decodeUtf8(input)
    };

    // Remove the query parameters from the URL.
    private func removeQuery(str: Text): Text {
        return Option.unwrap(Text.split(str, #char '?').next());
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:     UPDATING      CONTENT    ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // Update the page title
    // dfx canister call webpage update_page_title '("The new page title")'
    // Should give: "The new page title"
    public shared ({ caller }) func update_page_title(title : Text) : async Text {
        Debug.print("update_page_title called by " # debug_show(caller) # ". New title: " # title);
        page_title := title;
        page_title
    };

    // Update the page content
    // dfx canister call webpage update_page_content '("The new page content")'
    // Should give: "The new page content"
    public shared ({ caller }) func update_page_content(content : Text) : async Text {
        Debug.print("update_page_content called by " # debug_show(caller) # ". New content: " # content);
        page_content := content;
        page_content
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:     HANDLING    HTTP REQS    ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // Serve HTTP requests
    // dfx canister call webpage http_request '(record {url="/"; method="GET"; body=vec {}; headers=vec {}})'
    // (record {body=vec {77; 111; 116; 111; 107; 111; 32; 66; 111; 111; 116; 99; 97; 109; 112; 32; 50; 48; 50; 51}; headers=vec {record {"content-type"; "text/plain"}}; streaming_strategy=null; status_code=200})
    public query func http_request(req : HttpRequest) : async HttpResponse {
        Debug.print("HTTP Request --- " # debug_show (req.method) # " " # debug_show (req.url));
        switch (req.method, not Option.isNull(Array.find(req.headers, isGzip)), req.url) {
            case ("GET", false, "/stream") {
                {
                    status_code = 200 : Nat16;
                    headers = [("content-type", "text/plain")];
                    body = Text.encodeUtf8("Counter");
                    // If the streaming_strategy field of the HttpResponse is set, the HTTP Gateway then uses further query calls to obtain further chunks to append to the body.
                    // If the function reference in the callback field of the streaming_strategy is not a method of the given canister, the Gateway fails the request.
                    // Else, it makes a query call to the given method, passing the token value given in the streaming_strategy as the argument.
                    // That query method returns a StreamingCallbackHttpResponse. The body therein is appended to the body of the HTTP response.
                    // This is repeated as long as the method returns some token in the token field, until that field is null.
                    // Ref: https://internetcomputer.org/docs/current/references/ic-interface-spec#http-gateway-streaming
                    streaming_strategy = ?#Callback({
                        callback = http_streaming;
                        token = {
                            content_encoding = "";
                            index = 0;
                            key = "page_title"
                        }
                    });
                    upgrade = ?false
                }
            };
            case ("GET", false, _) {
                {
                    status_code = 200;
                    headers = [("content-type", "text/plain")];
                    // body = Text.encodeUtf8("Counter is " # Nat.toText(counter) # "\n" # req.url # "\n");
                    body = Text.encodeUtf8("page_title = " # page_title # "\n" # "page_content" # page_content);
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
                    // If the canister sets upgrade = opt true in the HttpResponse reply from http_request, then the Gateway ignores all other fields of the reply.
                    status_code = 204;
                    headers = [];
                    body = "";
                    streaming_strategy = null;
                    // If we receive a POST request, indicate that we want to perform an update. This will then call the http_request_update method.
                    // The HTTP request received here will then be passed to the http_request_update method for further processing.
                    // The response from http_request_update is then sent back to the caller.
                    // Ref: https://internetcomputer.org/docs/current/references/ic-interface-spec#upgrade-to-update-calls
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

    // If the canister sets upgrade = opt true in the HttpResponse reply from http_request, then the Gateway ignores all other fields of the reply.
    // The Gateway performs an update call to http_request_update, passing the same HttpRequest record as the argument, and uses that response instead.
    // The value of the upgrade field returned from http_request_update is ignored.
    // Ref: https://internetcomputer.org/docs/current/references/ic-interface-spec#upgrade-to-update-calls
    public func http_request_update(req : HttpRequest) : async HttpResponse {
        let decodedResponse : DecodedHttpRequest = decodeRequestBody(req);
        let decodedBody = decodedResponse.body;
        Debug.print("HTTP Update --- " # debug_show (req.method) # " " # debug_show (req.url));
        Debug.print("Decoded Body: " # debug_show (decodedBody));

        // Work out what (if anything) we need to update.
        let newPageTitle : Text = "";
        let newPageContent : Text = "";
        let updatingPageTitle = Text.contains(decodedBody, pattern_pt);
        let updatingPageContent = Text.contains(decodedBody, pattern_pc);

        if (updatingPageTitle) {
            // page_title = "New Title" page_contents = "New contents"
            // would return
            // (opt ""New Title" page_contents = "New contents"")
            let newPageTitle : Text = Option.get(Text.stripStart(decodedBody, pattern_pt), "");
        };

        if (updatingPageContent) {
            let newPageContent : Text = Option.get(Text.stripStart(decodedBody, pattern_pc), "");
        };

        let characters : Iter.Iter<Char> = Text.toIter(decodedBody);

        for (c in characters) {
            
        };

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
                // Return gzip encoded content.
                counter += 1;
                {
                    status_code = 201;
                    headers = [("content-type", "text/plain"), ("content-encoding", "gzip")];
                    // No library to do this at the moment in motoko, so this is manual input.
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

    // Streaming strategy callback.
    // This query method returns a StreamingCallbackHttpResponse. The body of this response is appended to the body of the parent HTTP response.
    // This is repeated as long as this method returns some token in the token field, until that field is null.
    public query func http_streaming(token : StreamingCallbackToken) : async StreamingCallbackResponse {
        switch (token.key) {
            case "page_title" {
                {
                    body = Text.encodeUtf8(page_title);
                    token = ?{
                        content_encoding = token.content_encoding;
                        index = token.index;
                        key = "next"
                    }
                }
            };
            case "next" {
                {
                    body = Text.encodeUtf8("\n");
                    token = ?{
                        content_encoding = token.content_encoding;
                        index = token.index;
                        key = "page_content"
                    }
                }
            };
            case "page_content" {
                {
                    body = Text.encodeUtf8("page_content");
                    token = null
                }
            };
            case _ { Prelude.unreachable() }
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:       ADMIN     ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    func is_admin (principal : Principal,) : Bool {
        switch (Array.find<Principal>(admins, func (x) { x == principal })) {
            case (?a) true;
            case _ false;
        };
    };

    public shared func get_admins () : async [Principal] {
        admins;
    };

    public shared ({ caller }) func remove_admins (removals : [Principal]) : async () {
        Debug.print("remove_admins called by " # debug_show(caller));
        assert(is_admin(caller));
        admins := Array.filter<Principal>(admins, func (admin) {
            Option.isNull(Array.find<Principal>(removals, func (x) { x == admin }));
        });
    };

    public shared ({ caller }) func addAdmins (newAdmins : [Principal]) : async () {
        Debug.print("addAdmins called by " # debug_show(caller));
        assert(is_admin(caller));
        admins := Array.append(admins, Array.filter<Principal>(newAdmins, func (x) {
            Option.isNull(Array.find<Principal>(admins, func (y) { x == y }));
        }));
    };

    public shared ({ caller }) func admin_function () : async Text {
        Debug.print("admin_function called by " # debug_show(caller));
        assert(is_admin(caller));
        "Hello, admin!";
    };

    // Get the cycles balance
    public query func cycle_balance() : async Nat {
        let balance = Cycles.balance();
        Debug.print("Cycles balance: " # debug_show(balance));
        return balance;
    };

    // Receive cycles
    public shared ({ caller }) func receive_cycles() : async Result.Result<Text, Text> {
        let cycles = Cycles.available();
        Debug.print("Received and accepted cycles: " # debug_show(cycles));
        ignore Cycles.accept(cycles);
        return #ok("Thanks!.")
    };

    public shared ({ caller }) func send_cycles (principalID : Text) : async Result.Result<Text, Text> {
        Debug.print("Current balance: " # Nat.toText(Cycles.balance()));
        let recipient : actor {  receive_cycles : () -> async Result.Result<Text, Text>; } = actor(principalID);
        Cycles.add(1_000_000_100);
        let send = await recipient.receive_cycles();
        Debug.print("Unused balance: " # Nat.toText(Cycles.refunded()));
        send
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      HELPERS    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    func isGzip(x : HeaderField) : Bool {
        checkGzip and Text.map(x.0, Prim.charToLower) == "accept-encoding" and Text.contains(Text.map(x.1, Prim.charToLower), #text "gzip")
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:       MISC      ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // dfx canister call webpage increment
    public func increment() : async Nat {
        counter += 1;

        let blob_temp : Blob = Text.encodeUtf8(Nat.toText(counter));
        CertifiedData.set(blob_temp);

        return counter;
    };

    // dfx canister call webpage getCounterValue
    public shared query func getCounterValue() : async CertifiedCounter {
        let validation : CertifiedCounter = {
            certificate = CertifiedData.getCertificate();
            value = counter;
        };

        return validation;
    }
}
