terraform {
  backend "s3" {
    key    = "infra-base/terraform.tfstate"
    region = "ap-northeast-1"
    # 버킷 이름은 깃허브 노출 방지를 위해 init 명령어 시점에 주입합니다.
  }
}
