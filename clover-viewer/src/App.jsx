import Viewer from "@samvera/clover-iiif/viewer";

const manifestUrl = new URLSearchParams(window.location.search).get('manifest');

const viewerOptions = {
    canvasBackgroundColor: '#252523',
    canvasHeight: 'auto',
    openSeadragon: {
        gestureSettingsMouse: {
            scrollToZoom: true
        }
    },
    showIIIFBadge: false,
    showMediaSearch: false,
    informationPanel: {
        open: false
    }
};

export default function App() {
    return (
        <main className="app">
            <div className="viewer" style={{ position: "relative", height: "80vh", zIndex: "0" }}>
                <Viewer
                    iiifContent={manifestUrl}
                    options={viewerOptions}
                />
            </div>
        </main>
    );
}