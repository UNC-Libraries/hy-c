import { useEffect } from "react";
import Viewer from "@samvera/clover-iiif/viewer";

const manifestUrl = new URLSearchParams(window.location.search).get('manifest');

const viewerOptions = {
    canvasBackgroundColor: '#252523',
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
    useEffect(() => {
        const postHeight = () => {
            const html = document.documentElement;
            const body = document.body;
            const height = Math.max(
                html ? html.scrollHeight : 0,
                html ? html.offsetHeight : 0,
                body ? body.scrollHeight : 0,
                body ? body.offsetHeight : 0
            );

            window.parent.postMessage({ type: "clover:height", height }, window.location.origin);
        };

        postHeight();

        if (typeof ResizeObserver !== "undefined") {
            const observer = new ResizeObserver(postHeight);
            observer.observe(document.documentElement);
            return () => observer.disconnect();
        }

        window.addEventListener("resize", postHeight);
        return () => window.removeEventListener("resize", postHeight);
    }, []);

    return (
        <main className="app">
            <div className="viewer">
                <Viewer
                    iiifContent={manifestUrl}
                    options={viewerOptions}
                />
            </div>
        </main>
    );
}