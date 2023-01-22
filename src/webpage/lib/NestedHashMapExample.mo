import HashMap "mo:base/HashMap";
import Text "mo:base/Text";

actor {
  let map = HashMap.HashMap<Text, HashMap.HashMap<Text,Text>>(0, Text.equal, Text.hash);

  // HashMap pass by reference test.
  // We update the nested HashMap, not the parent HashMap, but when we read it, the parent HashMap is updated.
  public shared func write () {
    map.put("a", HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash));
    switch (map.get("a")) {
      case (?nestedMap) nestedMap.put("b", "c");
      case _ ();
    };
  };

  public shared func read () {
    switch (map.get("a")) {
      case (?nestedMap) assert(nestedMap.get("b") == ?"c");
      case _ assert(false);
    }
  };

}