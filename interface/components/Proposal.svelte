<script>
    import { decodeUtf8 } from "../lib.js"
    export let post
  </script>
  
  <div class="post-preview">
    <h2>[{post.id}] {post.payload.proposal_summary}</h2>
    <p>Created: {new Date(Number.parseInt(post.timestamp / BigInt(1000000)))}</p>
    <p>State: {Object.keys(post.state)[0]}</p>
    <p>Proposer: {post.proposer.toString()}</p>

    <h2>Payload Details</h2>
    <p>Canister ID: {post.payload.canister_id}</p>
    <p>Canister Method: {post.payload.canister_method}</p>
    <p>Canister Message: {decodeUtf8(post.payload.canister_message)}</p>

    <h2>Vote Statistics</h2>
    <p>
      Yes: {BigInt(post.votes_yes.amount_e8s / BigInt(100000000)).toString()}, 
      No: {BigInt(post.votes_no.amount_e8s / BigInt(100000000)).toString()}
    </p>
  </div>
  
  <style>
    .post-preview {
      border: 1px solid white;
      border-radius: 10px;
      margin-bottom: 2vmin;
      padding: 2vmin;
    }
    h2 {
      color: white;
    }
  
    p {
      color: white;
    }
  </style>
  