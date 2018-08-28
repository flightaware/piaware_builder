node(label: 'raspberrypi') {
    def dists = ["stretch", "jessie", "wheezy"]
    def srcdir = "${WORKSPACE}/src"

    stage('Checkout') {
        sh "rm -fr ${srcdir}"
        sh "mkdir ${srcdir}"
        dir(srcdir) {
            checkout scm
        }
    }

    for (int i = 0; i < dists.size(); ++i) {
        def dist = dists[i]
        def pkgdir = "package-${dist}"
        def results = "results-${dist}"

        stage("Prepare source for ${dist}") {
            sh "rm -fr ${pkgdir}"
            sh "${srcdir}/sensible-build.sh ${dist} ${pkgdir}"
        }

        stage("Build for ${dist}") {
            sh "rm -fr ${results}"
            sh "mkdir -p ${results}"
            dir(pkgdir) {
                if (dist == "wheezy") {
                    sh "DIST=${dist} pdebuild --debbuildopts -b --buildresult ${WORKSPACE}/${results}"
                } else {
                    sh "DIST=${dist} pdebuild --use-pdebuild-internal --debbuildopts -b --buildresult ${WORKSPACE}/${results}"
                }
            }
            archiveArtifacts artifacts: "${results}/*.deb", fingerprint: true
        }

        stage("Test install on ${dist}") {
            sh "/build/repo/validate-packages.sh ${dist} ${results}/piaware_*.deb"
        }
    }

    if (env.BRANCH_NAME == "master" || env.BRANCH_NAME == "dev") {
        stage("Deploy to staging repo") {
            for (int i = 0; i < dists.size(); ++i) {
                def dist = dists[i]
                def results = "results-${dist}"
                sh "/build/repo/deploy-packages.sh ${dist} ${results}/*.deb"
            }
        }
    }
}
