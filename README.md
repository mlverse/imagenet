## Instance Configuration

```
gcloud init

gcloud beta compute --project=rstudio-cloudml instances create-with-container imagenet-2 --zone=us-central1-c --machine-type=n1-standard-8 --subnet=default --network-tier=PREMIUM --metadata=google-logging-enabled=true --maintenance-policy=TERMINATE --service-account=226719675476-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --accelerator=type=nvidia-tesla-k80,count=1 --image=cos-stable-81-12871-1160-0 --image-project=cos-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=imagenet-2 --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --container-image=mlverse/mlverse-base:version-0.2.2 --container-restart-policy=always --labels=container-vm=cos-stable-81-12871-1160-0

gcloud compute ssh tf-imagenet

wget http://us.download.nvidia.com/tesla/440.95.01/NVIDIA-Linux-x86_64-440.95.01.run
chmod +x NVIDIA-Linux-x86_64-440.95.01.run
sudo ./NVIDIA-Linux-x86_64-440.95.01.run
```

Format Local SSD properly, see [google.com/compute/docs/dist/local-ssd](https://cloud.google.com/compute/docs/disks/local-ssd#format_and_mount_a_local_ssd_device). We also [disable write cache flushing](https://cloud.google.com/compute/docs/disks/optimizing-local-ssd-performance#disable_flush) to improve local SDD performance.

```
sudo apt update
sudo apt install mdadm

lsblk
yes | sudo mdadm --create /dev/md0 --level=0 --raid-devices=4 /dev/nvme0n1 /dev/nvme0n2 /dev/nvme0n3 /dev/nvme0n4
sudo mkfs.ext4 -F /dev/md0
sudo mkdir -p /mnt/disks/localssd
sudo mount -o discard,defaults,nobarrier /dev/md0 /mnt/disks/localssd
sudo chmod a+w /mnt/disks/localssd
```

Run the image with the right volume,

```
docker pull mlverse/mlverse-base:version-0.2.2
docker run --gpus all --network host -v /mnt/disks/localssd:/localssd -d mlverse/mlverse-base:version-0.2.2
```

## Data Preprocessing

**Note:** You can potentially skip this section and reuse our public `r-imagenet` bucket which contains the partitioned dataset already.

We will preprocess ImageNet once in a single instance to partition in advance to support faster download times when running distributed.

```
mkdir /localssd/tmp
echo 'TMP=/localssd/tmp' > .Renviron
echo 'options(pins.path = "/localssd/pins")' > .Rprofile
```

```r
install.packages("remotes")
remotes::install_github("rstudio/pins")
```

Retrieve ImageNet, which might take a couple hours:

```r
pins::pin_get("c/imagenet-object-localization-challenge", board = "kaggle")[1] %>%
  untar(exdir = "/localssd/imagenet/")
```

Configure Google Cloud,

```bash
sudo apt-get install apt-transport-https ca-certificates gnupg curl
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-302.0.0-linux-x86_64.tar.gz
tar zxvf google-cloud-sdk-302.0.0-linux-x86_64.tar.gz google-cloud-sdk
echo "export PATH=\$PATH:~/google-cloud-sdk/bin/" > ~/.profile
gcloud init
```

Upload categories as a pin, which we manually downloaded from [ImageNet Classes Codes](https://www.quora.com/Where-can-I-find-the-semantic-labels-for-the-1000-ImageNet-ILSVRC2012-classes-codes) and saved as a CSV:

```
board_register("gcloud", name = "imagenet", bucket = "r-imagenet")
read.delim("categories.txt", sep = "|") %>% pin("categories", board = "imagenet")
```

Repartition by category and upload,

```
for (path in dir("/localssd/imagenet/ILSVRC/Data/CLS-LOC/train/", full.names = TRUE)) {
  # re-register board every 10 uploads to refresh authentication headers
  if (runif(1) > 0.9) r
    board_register("gcloud", name = "imagenet", bucket = "r-imagenet")
  
  # upload imagenet partition
  dir(path, full.names = TRUE) %>% pin(name = basename(path), board = "imagenet", zip = TRUE)
}
```

## Training Dry Run

Install dependencies,

```
install.packages("tensorflow")
install.packages("keras")
install.packages("remotes")

remotes::install_github("rstudio/pins")
remotes::install_github("r-tensorflow/alexnet")

tensorflow::install_tensorflow(version = "gpu")
tensorflow::tf_version()
tf$test$is_gpu_available()
```

Retrieve ImageNet subset from Google Storage,

```r
categories <- pins::pin_get("categories", board = "https://storage.googleapis.com/imagenet-pins/")
category_one <- pins::pin_get(categories[1], board = "https://storage.googleapis.com/imagenet-pins/")
```

## Training Distributed

Configure Spark,

```
install.packages(sparklyr)
spark_install()
```

Configure Spark Master,

```
/home/rstudio/spark/spark-2.4.3-bin-hadoop2.7/sbin/start-master.sh
```

Configure Spark Worker,

```
/home/rstudio/spark/spark-2.4.3-bin-hadoop2.7/sbin/start-slave.sh spark://tfimagenet.c.rstudio-cloudml.internal:7077
```

Connect to Spark from R driver,

```
sc <- spark_connect(master = "spark://tfimagenet.c.rstudio-cloudml.internal:7077", spark_home = "/home/rstudio/spark/spark-2.4.3-bin-hadoop2.7/")
```

## Other Resources

### CPU

```
top
```

### Network

```
sudo apt-get install iftop
iftop
```

### Disk

```
sudo apt-get install dstat
dstat
```

### Cleaning up

If the docker images need to be relaunched, consider freeing space with:

```
docker system prune
```
