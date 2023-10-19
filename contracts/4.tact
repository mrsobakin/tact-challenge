import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time;
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message NftWithdrawal {
  queryId: Int as uint64;
  nftAddress: Address;
}

struct HeldNft {
  releaseTime: Int as uint32;
  owner: Address;
  nft: Address;
}

contract Task4 with Deployable {
  seed: Int as uint128;
  heldNft: HeldNft?;
  
  init(seed: Int) {
    self.seed = seed;
    self.heldNft = null;
  }

  receive(msg: OwnershipAssigned) {
    if(self.heldNft != null) {
      sendNft(sender(), msg.prevOwner, SendRemainingValue);
      return;
    }
    
    self.heldNft = HeldNft {
      releaseTime: now() + msg.forwardPayload.loadInt(32),
      owner: msg.prevOwner,
      nft: sender()
    };
  }

  receive(msg: NftWithdrawal) {
    require(self.heldNft != null, "No NFT is held");
    require(sender() == (self.heldNft!!).owner, "Invalid sender");
    if(now() < (self.heldNft!!).releaseTime) {
      self.reply("NFT is still locked".asComment());
      return;
    }
    sendNft((self.heldNft!!).nft, (self.heldNft!!).owner, SendRemainingBalance);
  }

  fun sendNft(nft: Address, owner: Address, mode: Int) {
    send(SendParameters {
      to: msg.nftAddress,
      bounce: true,
      value: 0,
      mode: SendIgnoreErrors + mode,
      body: Transfer {
        queryId: 0,
        newOwner: owner,
        responseDestination: owner,
        customPayload: null,
        forwardAmount: ton("0.01"),
        forwardPayload: emptySlice()
      }.toCell()
    });
  }

  get fun time(): Int {
    if(self.heldNft == null) {
      return 0;
    }
    return now() - (self.heldNft!!).releaseTime;
  }

  get fun nft(): Address? {
    if(self.heldNft == null) {
      return null;
    }
    return (self.heldNft!!).owner;
  }

  get fun owner(): Address? {
    if(self.heldNft == null) {
      return null;
    }
    return (self.heldNft!!).nft;
  }
}