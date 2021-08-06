var nextSectionNumber = 2;
var currentSectionNumber = 1;

function addSection() {
    var nextChildUp = 'child' + this.nextSectionNumber;
    var nextSection = document.getElementById(nextChildUp);

    if (this.nextSectionNumber <= 5) {
        nextSection.style.display = 'block';
        this.nextSectionNumber = this.nextSectionNumber + 1;
        this.currentSectionNumber = this.currentSectionNumber + 1;
        if (this.nextSectionNumber > 2) {
            document.getElementById('remove-button').style.display = 'block';
        }
        if (this.nextSectionNumber > 5) {
            document.getElementById('add-button').style.display = 'none';
        }
    }
}

function removeSection() {
    var currentChild = 'child' + this.currentSectionNumber;
    var currentSection = document.getElementById(currentChild);

    if (this.currentSectionNumber > 1) {
        currentSection.style.display = 'none';
        this.nextSectionNumber = this.nextSectionNumber - 1;
        this.currentSectionNumber = this.currentSectionNumber - 1;
        if (this.currentSectionNumber < 2) {
            document.getElementById('remove-button').style.display = 'none';
        }
        if (this.nextSectionNumber < 5) {
            document.getElementById('add-button').style.display = 'block';
        }
    }
}