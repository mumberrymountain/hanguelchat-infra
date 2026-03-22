terraform {
  backend "s3" {
    bucket = "hanguelchat-state-bucket"
    key = "terraform.tfstate"
    region = "ap-northeast-2"
  }
}

