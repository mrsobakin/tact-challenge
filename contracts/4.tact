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

contract Task4 with Deployable {
  seed: Int as uint128;
  releaseTime: Int? as uint32;
  owner: Address?;
  nft: Address?;
  
  init(seed: Int) {
    self.seed = seed;
    self.releaseTime = null;
    self.owner = null;
    self.nft = null;
  }

  receive(msg: OwnershipAssigned) {
    if(self.releaseTime != null) {
      self.sendNft(msg.queryId, sender(), msg.prevOwner);
      return;
    }
    
    self.releaseTime = now() + msg.forwardPayload.loadUint(32);
    self.owner = msg.prevOwner;
    self.nft = sender();
  }

  receive(msg: NftWithdrawal) {
    require(self.nft != null, "No NFT is held");
    require(sender() == self.owner!!, "Invalid sender");
    require(msg.nftAddress == self.nft!!, "Locker does not hold such NFT");

    if(now() < self.releaseTime!!) {
      self.reply("NFT is still locked".asComment());
      return;
    }

    self.sendNft(
      msg.queryId,
      self.nft!!, 
      self.owner!!
    );
    self.releaseTime = null;
  }

  fun sendNft(queryId: Int, nft: Address, owner: Address) {
    send(SendParameters {
      to: nft,
      bounce: true,
      value: 0,
      mode: SendIgnoreErrors + SendRemainingValue,
      body: Transfer {
        queryId: queryId,
        newOwner: owner,
        responseDestination: owner,
        customPayload: null,
        forwardAmount: 0,
        forwardPayload: emptySlice()
      }.toCell()
    });
  }

  get fun time(): Int {
    if(self.nft == null) {
      return 0;
    }
    let untilRelease: Int = (self.releaseTime!!) - now();
    if(untilRelease >= 0) {
      return untilRelease;
    } else {
      return 0;
    }
  }

  get fun nft(): Address? {
    if(self.nft == null) {
      return null;
    }
    return (self.nft!!);
  }

  get fun owner(): Address? {
    if(self.nft == null) {
      return null;
    }
    return (self.owner!!);
  }
}