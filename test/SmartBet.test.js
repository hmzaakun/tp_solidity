const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SmartBet", function () {
  let smartBet;
  let admin, user1, user2, user3, otherUsers;
  const entryFee = ethers.parseEther("0.1");

  beforeEach(async function () {
    [admin, user1, user2, user3, ...otherUsers] = await ethers.getSigners();
    const SmartBet = await ethers.getContractFactory("SmartBet");
    smartBet = await SmartBet.deploy(entryFee);
  });

  describe("User Registration", function () {
    it("allows a user to register with a pseudo", async function () {
      await expect(smartBet.connect(user1).registerUser("UserOne"))
        .to.emit(smartBet, "UserRegistered")
        .withArgs(user1.address, "UserOne");

      const userInfo = await smartBet.users(user1.address);
      expect(userInfo.pseudo).to.equal("UserOne");
      expect(userInfo.isRegistered).to.be.true;
    });
  });

  describe("Placing Bets", function () {
    it("allows a registered user to place a bet on a match", async function () {
      await smartBet.connect(admin).addMatch(1, 123456789);
      await smartBet.connect(user1).registerUser("UserOne");
      await expect(smartBet.connect(user1).placeBet(1, 2, 1, { value: entryFee }))
        .to.emit(smartBet, "BetPlaced")
        .withArgs(user1.address, 1, 2, 1);

      const bet = await smartBet.matchBets(1, 0);
      expect(bet.predictedScoreHome).to.equal(2);
      expect(bet.predictedScoreAway).to.equal(1);
    });
  });

  describe("Admin Functions", function () {
    it("allows admin to add a match", async function () {
      await expect(smartBet.connect(admin).addMatch(1, 123456789))
        .to.emit(smartBet, "MatchAdded") // Assuming you have this event
        .withArgs(1, 123456789);

      const matchInfo = await smartBet.matches(1);
      expect(matchInfo.date).to.equal(123456789);
    });
  });

  describe("Setting Match Results and Determining Winners", function () {
    beforeEach(async function () {
      await smartBet.connect(admin).addMatch(1, 123456789);
      await smartBet.connect(user1).registerUser("UserOne");
      await smartBet.connect(user2).registerUser("UserTwo");
      await smartBet.connect(user1).placeBet(1, 2, 1, { value: entryFee });
      await smartBet.connect(user2).placeBet(1, 2, 1, { value: entryFee });
    });

    it("allows admin to set match results and correctly determines winners", async function () {
      await expect(smartBet.connect(admin).setMatchResult(1, 2, 1))
        .to.emit(smartBet, "WinnersPaid")
        .withArgs(1);

      // Assuming totalPool is updated correctly and winners are paid
      // You might need to adjust the logic based on how winners are determined
      expect(await ethers.provider.getBalance(smartBet.address)).to.be.below(entryFee.mul(2));
    });
  });
});
