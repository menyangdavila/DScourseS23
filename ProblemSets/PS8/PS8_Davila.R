library(nloptr)
library(modelsummary)

## Question 4
set.seed(100)

N <- 100000
K <- 10

# Generate matrix X with normally distributed random numbers
X <- matrix(rnorm(N*K), nrow=N, ncol=K)

# Replace the first column of X with a column of 1s
X[,1] <- rep(1, N)

# Generate vector eps with random numbers distributed N(0, s^2)
s <- 0.5
eps <- rnorm(N, mean=0, sd=s)

# Generate vector beta with the given values
beta <- c(1.5, -1, -0.25, 0.75, 3.5, -2, 0.5, 1, 1.25, 2)

# Generate vector Y as Xb + eps
Y <- X %*% beta + eps



## Question 5
# Estimate beta using matrices
beta_hat <- solve(t(X) %*% X) %*% t(X) %*% Y
# The estimates are very close to the true beta.



## Question 6
# Set the learning rate for gradient descent
learning_rate <- 0.0000003

# Initialize beta to all zeros
beta_gradient <- rnorm(K)

# Define the gradient function
grad <- function(beta_gradient) {
  return(-2 * t(X) %*% (Y - X %*% beta_gradient))
}

# Perform gradient descent
for (i in 1:1000) {
  beta_gradient <- beta_gradient - learning_rate * grad(beta_gradient)
}

# Print beta_hat
beta_gradient
 


## Question 7 - nloptr
# Objective function
objfun <- function(beta_nloptr,Y,X) {
  return (sum((Y-X%*%beta_nloptr)^2))
}

# Gradient of our objective function
gradient <- function(beta_nloptr,Y,X) {
  return ( as.vector(-2*t(X)%*%(Y-X%*%beta_nloptr)) )
}

# initial values
beta0 <- runif(dim(X)[2]) #start at uniform random numbers equal to number of coefficients
# Algorithm parameters
options <- list("algorithm"="NLOPT_LD_LBFGS","xtol_rel"=1.0e-6,"maxeval"=1e3)
# Optimize!
result <- nloptr( x0=beta0,eval_f=objfun,eval_grad_f=gradient,opts=options,Y=Y,X=X)
print(result)



## Question 7 - Nelder-Mead
# Objective function
objfun <- function(beta_nm, Y, X) {
  return (sum((Y-X%*%beta_nm)^2))
}

# Gradient of our objective function
gradient <- function(beta_nm,Y,X) {
  return ( as.vector(-2*t(X)%*%(Y-X%*%beta_nm)) )
}

# initial values
betastat <- runif(K)

# Algorithm parameters
options <- list("algorithm"="NLOPT_LN_NELDERMEAD","xtol_rel"=1.0e-6,"maxeval"=1e3)
# Optimize!
result <- nloptr(x0=betastat,eval_f=objfun,eval_grad_f=gradient,opts=options,Y=Y,X=X)
print(result)
# Using nloptr's L-BFGS and Nelder-Mead algorithm gives very similar estimates.



## Question 8
# Our objective function
objfun  <- function(theta,Y,X) {
  # need to slice our parameter vector into beta and sigma components
  beta    <- theta[1:(length(theta)-1)]
  sig     <- theta[length(theta)]
  # write objective function as *negative* log likelihood (since NLOPT minimizes)
  loglike <- -sum( -.5*(log(2*pi*(sig^2)) + ((Y-X%*%beta)/sig)^2) ) 
  return (loglike)
}

# Gradient of our objective function
gradient <- function (theta,Y,X) {
  grad <- as.vector ( rep (0, length ( theta )))
  beta <- theta [1:( length ( theta ) -1)]
  sig <- theta [ length ( theta )]
  grad [1:( length ( theta ) -1)] <- -t(X)%*%(Y - X%*% beta )/( sig ^2)
  grad [ length ( theta )] <- dim (X) [1] /sig - crossprod (Y-X%*% beta )/( sig
                                                                            ^3)
  return (grad)
}

# initial values
theta0 <- runif(K)
theta0 <- append(as.vector(summary(lm(Y~X - 1))$coefficients[,1]),runif(1))

# Algorithm parameters
options <- list("algorithm"="NLOPT_LN_NELDERMEAD","xtol_rel"=1.0e-6,"maxeval"=1e4)
# Optimize!
result <- nloptr( x0=theta0,eval_f=objfun,opts=options,Y=Y,X=X)
print(result)



## Question 9
ylm <- lm(Y ~ X -1)
modelsummary(ylm, output="latex")
