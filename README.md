## Instance Configuration

```
gcloud init

gcloud beta compute --project=rstudio-cloudml instances create tfimagenet --zone=us-central1-c --machine-type=n1-standard-4 --subnet=default --network-tier=PREMIUM --maintenance-policy=TERMINATE --service-account=226719675476-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --accelerator=type=nvidia-tesla-k80,count=1 --image=c0-common-gce-gpu-image-20200128 --image-project=ml-images --boot-disk-size=500GB --boot-disk-type=pd-standard --boot-disk-device-name=tfimagenet --reservation-affinity=any

gcloud compute ssh tfimagenet

wget http://us.download.nvidia.com/tesla/440.95.01/NVIDIA-Linux-x86_64-440.95.01.run
chmod +x NVIDIA-Linux-x86_64-440.95.01.run
sudo ./NVIDIA-Linux-x86_64-440.95.01.run
```

Format Local SSD properly, see [google.com/compute/docs/dist/local-ssd](https://cloud.google.com/compute/docs/disks/local-ssd#format_and_mount_a_local_ssd_device). We also [disable write cache flushing](https://cloud.google.com/compute/docs/disks/optimizing-local-ssd-performance#disable_flush) to improve local SDD performance.

```
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

## R Configuration

```
mkdir /localssd/tmp
echo 'TMP=/localssd/tmp' > .Renviron
echo 'options(pins.path = "/localssd/pins")' > .Rprofile
```

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

Retrieve ImageNet,

```r
pins::pin_get("c/imagenet-object-localization-challenge", board = "kaggle")
# untar(pins::pin_get("c/imagenet-object-localization-challenge", board = "kaggle")[1], exdir = "imagenet/")
```

Configure Google Cloud for re-upload,

```bash
sudo apt-get install apt-transport-https ca-certificates gnupg curl
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-302.0.0-linux-x86_64.tar.gz
tar zxvf google-cloud-sdk-302.0.0-linux-x86_64.tar.gz google-cloud-sdk
echo "export PATH=\$PATH:~/google-cloud-sdk/bin/" > ~/.profile
gcloud init
```

Reupload ImageNet, strictly encouraged to use devel version of pins to avoid copying 250GB twice,

```r
install.packages("remotes")
remotes::install_github("rstudio/pins")
```

```r
library(pins)

pin_get("c/imagenet-object-localization-challenge", board = "kaggle") %>%
  pin("imagenet", board = "gcloud", retrieve = FALSE)
```

Retrieve imagenet from Google Storage,

```r
imagenet <- pins::pin_get("imagenet", board = "https://storage.googleapis.com/imagenet-pins/")
untar(imagenet[1], exdir = "/localssd/imagenet/")
```

Retrieve ImageNet subset,

```
dir.create("small")

imagenet_categories <- function() {
  dir("imagenet/ILSVRC/Data/CLS-LOC/train")
}

imagenet_subset <- function(category = "n01440764") {
  dest <- file.path("small", category)
  dir.create(dest, recursive = TRUE)
  file.copy(
    dir(file.path("imagenet/ILSVRC/Data/CLS-LOC/train", category), full.names = TRUE),
    dest
  )
  
  length(dir(dest))
}

imagenet_subset(imagenet_categories()[1])
imagenet_subset(imagenet_categories()[2])
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
