const toInterest = (interest) => {
  return (interest * 10000).toFixed(0)
}

const getInterestRate = (borrowRatio, duration) => {
  const baseInterestRate = 0.2 * borrowRatio + 0.5 * borrowRatio ** 2;
  const penaltyInterestRate = duration / 31536000;
  const interestRate = baseInterestRate + penaltyInterestRate;
  return Math.floor(interestRate * 10000) / 10000
}

module.exports = {
  toInterest,
  getInterestRate
}